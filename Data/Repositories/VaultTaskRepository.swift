import Foundation

/// TaskNotes notes in the vault folder. Every write is coordinated and atomic, changes exactly
/// the keys it was asked to, and is applied to the latest file version ("last edit wins").
actor VaultTaskRepository: TaskRepository {
    private let location: VaultLocating
    private let fileSystem: NoteFileSystem
    private let scanner: @Sendable (AppSettings.Vault) -> VaultScanner
    private let writer: TaskNoteWriter
    private let readerFactory: @Sendable (AppSettings.Vault) -> TaskNoteReader
    private let vaultSettings: @Sendable () -> AppSettings.Vault
    private let backups: BackupService
    private let ubiquity: UbiquityService
    private let clock: Clock
    private let noteExtension: String
    private var seenModification: [String: Date] = [:]

    init(location: VaultLocating, fileSystem: NoteFileSystem, ubiquity: UbiquityService, mapping: FieldMapping,
         calendar: Calendar, rules: RulesConfig.Vault, backups: BackupService, clock: Clock,
         vaultSettings: @escaping @Sendable () -> AppSettings.Vault) {
        self.location = location
        self.fileSystem = fileSystem
        self.ubiquity = ubiquity
        self.writer = TaskNoteWriter(mapping: mapping, timeZone: calendar.timeZone)
        let readerFactory: @Sendable (AppSettings.Vault) -> TaskNoteReader = {
            TaskNoteReader(mapping: mapping, taskTag: $0.taskTag, calendar: calendar)
        }
        self.readerFactory = readerFactory
        self.scanner = { settings in
            VaultScanner(fileSystem: fileSystem, ubiquity: ubiquity, reader: readerFactory(settings),
                         noteExtension: rules.noteExtension, downloadTimeout: rules.downloadTimeoutSeconds)
        }
        self.vaultSettings = vaultSettings
        self.backups = backups
        self.clock = clock
        self.noteExtension = rules.noteExtension
    }

    func scan() async throws -> VaultScanResult {
        let settings = vaultSettings()
        let scanner = scanner(settings)
        let output = try await location.withRoot { root in await scanner.scan(root: root, tasksFolder: settings.tasksFolder) }
        seenModification = output.modificationDates
        return output.result
    }

    func apply(_ changes: [TaskFieldChange], to task: TaskNote) async throws -> TaskWriteResult {
        try await edit(task) { document in
            self.writer.apply(changes, to: &document, now: self.clock.now)
            return document.text
        }
    }

    func body(of task: TaskNote) async throws -> String {
        try await location.withRoot { root in
            let file = try fileSystem.read(try existingURL(of: task, root: root))
            return try FrontmatterDocument(text: file.text).body
        }
    }

    func setBody(_ body: String, of task: TaskNote) async throws -> TaskWriteResult {
        try await edit(task) { document in
            self.writer.apply([], to: &document, now: self.clock.now)
            let frontmatter = Array(document.text.utf8.dropLast(document.body.utf8.count))
            return String(decoding: frontmatter + Array(body.utf8), as: UTF8.self)
        }
    }

    func rename(_ task: TaskNote, to newName: String, dependents: [TaskNote]) async throws -> TaskNote {
        try NoteNameRules.validate(newName)
        let renamed: TaskNote = try await location.withRoot { root in
            let source = try existingURL(of: task, root: root)
            let target = source.deletingLastPathComponent().appendingPathComponent("\(newName).\(noteExtension)")
            let siblings = (try? fileSystem.listFiles(in: source.deletingLastPathComponent())) ?? []
            if siblings.contains(where: { $0.deletingPathExtension().lastPathComponent.lowercased() == newName.lowercased() && $0 != source }) {
                throw TaskRepositoryError.nameTaken(newName)
            }
            try fileSystem.move(source, to: target)
            var result = task
            result.name = newName
            result.relativePath = VaultPaths.relative(target, to: root)
            seenModification[result.relativePath] = fileSystem.modificationDate(of: target)
            return result
        }
        for dependent in dependents {
            let links = dependent.previousTasks.map { $0 == task.name ? newName : $0 }
            _ = try await apply([.previousTasks(links)], to: dependent)
        }
        return renamed
    }

    func moveToTrash(_ task: TaskNote) async throws {
        let trashFolder = vaultSettings().trashFolder
        try await location.withRoot { root in
            let source = try existingURL(of: task, root: root)
            let trash = root.appendingPathComponent(trashFolder, isDirectory: true)
            var target = trash.appendingPathComponent(source.lastPathComponent)
            var counter = 1
            while fileSystem.fileExists(target) {
                target = trash.appendingPathComponent("\(task.name) \(counter).\(noteExtension)")
                counter += 1
            }
            try fileSystem.move(source, to: target)
        }
    }

    func backup(_ tasks: [TaskNote], reason: String) async throws {
        try await location.withRoot { root in
            _ = try backups.backup(tasks.map { root.appendingPathComponent($0.relativePath) }, reason: reason)
        }
    }

    func obsidianURL(for task: TaskNote) async -> URL? {
        try? await location.withRoot { root in
            var components = URLComponents()
            components.scheme = "obsidian"
            components.host = "open"
            let file = task.relativePath.hasSuffix(".\(noteExtension)") ? String(task.relativePath.dropLast(noteExtension.count + 1)) : task.relativePath
            components.queryItems = [URLQueryItem(name: "vault", value: root.lastPathComponent), URLQueryItem(name: "file", value: file)]
            return components.url
        }
    }

    // MARK: - Editing

    /// Reads the latest version, lets `transform` produce the new text, writes it atomically.
    private func edit(_ task: TaskNote, transform: @escaping (inout FrontmatterDocument) -> String) async throws -> TaskWriteResult {
        let reader = readerFactory(vaultSettings())
        return try await location.withRoot { root in
            let url = try existingURL(of: task, root: root)
            var hadConflict = (try? ubiquity.resolveConflictsKeepingLatest(url)) ?? false
            if let seen = seenModification[task.relativePath], let current = fileSystem.modificationDate(of: url),
               abs(current.timeIntervalSince(seen)) > 0.001 {
                hadConflict = true
            }
            let file = try fileSystem.read(url)
            var document: FrontmatterDocument
            do {
                document = try FrontmatterDocument(text: file.text)
            } catch {
                throw TaskRepositoryError.brokenFrontmatter(task.name)
            }
            let text = transform(&document)
            try fileSystem.write(text, to: url)
            seenModification[task.relativePath] = fileSystem.modificationDate(of: url)
            let updated = try FrontmatterDocument(text: text)
            return TaskWriteResult(task: reader.task(from: updated, name: task.name, relativePath: task.relativePath),
                                   hadConflict: hadConflict)
        }
    }

    private func existingURL(of task: TaskNote, root: URL) throws -> URL {
        let url = root.appendingPathComponent(task.relativePath)
        guard fileSystem.fileExists(url) else { throw TaskRepositoryError.fileMissing(task.name) }
        return url
    }
}

/// Obsidian-safe note names: no path separators or link syntax characters.
enum NoteNameRules {
    static let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|#^[]")

    static func validate(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed == name, !name.hasPrefix("."), name.count <= 200,
              name.rangeOfCharacter(from: forbidden) == nil else {
            throw TaskRepositoryError.invalidName(name)
        }
    }
}
