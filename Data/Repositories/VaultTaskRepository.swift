import Foundation

/// TaskNotes notes in the vault folder. Every write is coordinated and atomic, changes exactly
/// the keys it was asked to, and is applied to the latest file version ("last edit wins").
actor VaultTaskRepository: TaskStore, VersionConflictResolving, ExternalLinking, TaskBackups, FolderInspecting {
    private let location: VaultLocating
    private let fileSystem: NoteFileSystem
    private let scanner: @Sendable (AppSettings.Vault) -> VaultScanner
    private let writer: TaskNoteWriter
    private let mapping: FieldMapping
    private let readerFactory: @Sendable (AppSettings.Vault) -> TaskNoteReader
    private let vaultSettings: @Sendable () -> AppSettings.Vault
    private let backups: BackupService
    private let ubiquity: UbiquityService
    private let clock: Clock
    private let noteExtension: String
    private let obsidianVaultsFolder: String
    private let doneFolder: String
    private var seenModification: [String: Date] = [:]

    init(location: VaultLocating, fileSystem: NoteFileSystem, ubiquity: UbiquityService, mapping: FieldMapping,
         calendar: CalendarSource, rules: RulesConfig.Vault, backups: BackupService, clock: Clock,
         vaultSettings: @escaping @Sendable () -> AppSettings.Vault) {
        self.location = location
        self.fileSystem = fileSystem
        self.ubiquity = ubiquity
        self.writer = TaskNoteWriter(mapping: mapping, calendar: calendar)
        self.mapping = mapping
        let readerFactory: @Sendable (AppSettings.Vault) -> TaskNoteReader = {
            TaskNoteReader(mapping: mapping, taskTag: $0.taskTag, calendar: calendar.current)
        }
        self.readerFactory = readerFactory
        self.scanner = { settings in
            VaultScanner(fileSystem: fileSystem, ubiquity: ubiquity, reader: readerFactory(settings),
                         noteExtension: rules.noteExtension, downloadTimeout: rules.downloadTimeoutSeconds,
                         downloadPoll: rules.downloadPollSeconds)
        }
        self.vaultSettings = vaultSettings
        self.backups = backups
        self.clock = clock
        self.noteExtension = rules.noteExtension
        self.obsidianVaultsFolder = rules.obsidianVaultsFolder
        self.doneFolder = rules.doneFolder
    }

    func load() async throws -> VaultScanResult {
        let settings = vaultSettings()
        let scanner = scanner(settings)
        let output = try await location.withRoot { root in await scanner.scan(root: root, tasksFolder: settings.tasksFolder) }
        // A write may have landed while the scan was reading; keep the newer date.
        seenModification.merge(output.modificationDates) { current, scanned in max(current, scanned) }
        return output.result
    }

    func apply(_ changes: [TaskEdit], to task: TaskItem) async throws -> TaskWriteResult {
        try await edit(task, changes: changes) { document in
            self.writer.apply(changes, to: &document, now: self.clock.now)
            return document.text
        }
    }

    /// The text of the note without the app's ```SuperPooperApp block.
    func text(of task: TaskItem) async throws -> String {
        try await location.withRoot { root in
            let file = try fileSystem.read(try existingURL(of: task, root: root))
            return AppBlock.split(try FrontmatterDocument(text: file.text).body).visible
        }
    }

    /// Replaces the text of the note; the app's block (if any) stays right after the frontmatter.
    func setText(_ visible: String, of task: TaskItem) async throws -> TaskWriteResult {
        try await edit(task) { document in
            let body = AppBlock.join(block: AppBlock.split(document.body).block, visible: visible)
            self.writer.apply([], to: &document, now: self.clock.now)
            return document.text(withBody: body)
        }
    }

    func rename(_ task: TaskItem, to newName: String, dependents: [TaskItem]) async throws -> TaskItem {
        guard NoteNameRules.isValid(newName) else { throw TaskStoreError.invalidName(newName) }
        let renamed: TaskItem = try await location.withRoot { root in
            let source = try existingURL(of: task, root: root)
            let target = source.deletingLastPathComponent().appendingPathComponent("\(newName).\(noteExtension)")
            if NoteFolder(source.deletingLastPathComponent(), fileSystem: fileSystem).isTaken(newName, except: source) {
                throw TaskStoreError.nameTaken(newName)
            }
            try fileSystem.move(source, to: target)
            guard fileSystem.isMoved(source, to: target) else { throw TaskStoreError.notConfirmed(newName) }
            var result = task
            result.name = newName
            result.id = TaskID(relativePath: VaultPaths.relative(target, to: root))
            seenModification[result.id.relativePath] = fileSystem.modificationDate(of: target)
            return result
        }
        // A dependent that moved or vanished meanwhile must not undo the rename; its link then shows
        // up as "linked task not found" after the rescan.
        for dependent in dependents {
            _ = try? await edit(dependent) { document in
                self.writer.renameLinks(from: task.name, to: newName, in: &document, now: self.clock.now)
                return document.text
            }
        }
        return renamed
    }

    /// Into the vault's trash folder (Obsidian's `.trash`).
    func delete(_ task: TaskItem) async throws {
        let trashFolder = vaultSettings().trashFolder
        try await location.withRoot { root in
            let source = try existingURL(of: task, root: root)
            let trash = root.appendingPathComponent(trashFolder, isDirectory: true)
            let names = NoteFolder(trash, fileSystem: fileSystem)
            let name = UniqueName.free(source.deletingPathExtension().lastPathComponent, firstNumber: 1) { names.isTaken($0) }
            let target = trash.appendingPathComponent("\(name).\(noteExtension)")
            try fileSystem.move(source, to: target)
            guard fileSystem.isMoved(source, to: target) else { throw TaskStoreError.notConfirmed(task.name) }
        }
    }

    func fileAway(_ task: TaskItem) async throws {
        let settings = vaultSettings()
        try await location.withRoot { root in
            let source = try existingURL(of: task, root: root)
            let folder = try VaultPaths.besideTasks(doneFolder, root: root, tasksFolder: settings.tasksFolder, fileSystem: fileSystem)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let names = NoteFolder(folder, fileSystem: fileSystem)
            let name = UniqueName.free(source.deletingPathExtension().lastPathComponent) { names.isTaken($0) }
            let target = folder.appendingPathComponent("\(name).\(noteExtension)")
            try fileSystem.move(source, to: target)
            guard fileSystem.isMoved(source, to: target) else { throw TaskStoreError.notConfirmed(task.name) }
        }
    }

    func filedTasks() async throws -> [TaskItem] {
        let settings = vaultSettings()
        let scanner = scanner(settings)
        return try await location.withRoot { root in
            let folder = try VaultPaths.besideTasks(doneFolder, root: root, tasksFolder: settings.tasksFolder, fileSystem: fileSystem)
            guard fileSystem.fileExists(folder) else { return [] }
            return await scanner.scan(root: root, tasksFolder: VaultPaths.relative(folder, to: root)).result.tasks
        }
    }

    /// The note is written the way TaskNotes writes a new one (with the draft's status), then gets the draft's other
    /// fields and its text.
    func create(_ draft: NoteDraft, named name: String) async throws -> TaskItem {
        var task = try await createNote(named: name, status: draft.note.status)
        let fields = draft.changes.filter { if case .status = $0 { false } else { true } }
        if !fields.isEmpty { task = try await apply(fields, to: task).task }
        if !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { task = try await setText(draft.body, of: task).task }
        return task
    }

    nonisolated func nameProblem(in name: String) -> NoteNameProblem? {
        NoteNameRules.problem(in: name)
    }

    private func createNote(named name: String, status: TaskStatus) async throws -> TaskItem {
        guard NoteNameRules.isValid(name) else { throw TaskStoreError.invalidName(name) }
        let settings = vaultSettings()
        let reader = readerFactory(settings)
        let text = writer.newNote(tag: settings.taskTag, status: status, now: clock.now)
        return try await location.withRoot { root in
            let folder = root.appendingPathComponent(VaultPaths.tasksFolder(settings.tasksFolder, in: root, exists: fileSystem.fileExists),
                                                     isDirectory: true)
            let names = NoteFolder(folder, fileSystem: fileSystem)
            let finalName = UniqueName.free(name) { names.isTaken($0) }
            let url = folder.appendingPathComponent("\(finalName).\(noteExtension)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try fileSystem.write(text, to: url)
            guard fileSystem.isWritten(text, at: url) else { throw TaskStoreError.notConfirmed(finalName) }
            let relativePath = VaultPaths.relative(url, to: root)
            seenModification[relativePath] = fileSystem.modificationDate(of: url)
            return reader.task(from: try FrontmatterDocument(text: text), name: finalName, relativePath: relativePath)
        }
    }

    func backup(_ tasks: [TaskItem], reason: String) async throws {
        try await location.withRoot { root in
            _ = try backups.backup(tasks.map { root.appendingPathComponent($0.id.relativePath) }, reason: reason)
        }
    }

    /// `obsidian://open?vault=…&file=…`.
    func externalURL(for task: TaskItem) async -> URL? {
        let settings = vaultSettings()
        return try? await location.withRoot { root in
            VaultPaths.obsidianURL(relativePath: task.id.relativePath, root: root, folder: chosenFolder(root: root),
                                   vaultName: settings.obsidianVault, pathPrefix: settings.obsidianPathPrefix,
                                   noteExtension: noteExtension)
        }
    }

    func versions(of task: TaskItem) async throws -> [NoteVersion] {
        try await location.withRoot { root in try ubiquity.versions(of: try existingURL(of: task, root: root)) }
    }

    func keep(_ versionID: String, of task: TaskItem) async throws {
        try await location.withRoot { root in
            let url = try existingURL(of: task, root: root)
            try ubiquity.keep(versionID, of: url)
            seenModification[task.id.relativePath] = fileSystem.modificationDate(of: url)
        }
    }

    func chosenFolder() async -> ChosenFolder {
        (try? await location.withRoot { root in chosenFolder(root: root) }) ?? ChosenFolder()
    }

    private func chosenFolder(root: URL) -> ChosenFolder {
        ChosenFolder(isWholeVault: VaultPaths.isWholeVault(root, exists: fileSystem.fileExists),
                     obsidianPlace: VaultPaths.obsidianPlace(of: root, vaultsFolder: obsidianVaultsFolder))
    }

    // MARK: - Editing

    /// Reads the latest version, lets `transform` produce the new text, writes it atomically.
    /// Before writing, the file is compared with what the app saw: if it changed meanwhile, the edit lands on
    /// the latest version, and fields of `changes` that were changed there too are reported.
    private func edit(_ task: TaskItem, changes: [TaskEdit] = [],
                      transform: @escaping (inout FrontmatterDocument) -> String) async throws -> TaskWriteResult {
        let reader = readerFactory(vaultSettings())
        return try await location.withRoot { root in
            let url = try existingURL(of: task, root: root)
            // iCloud conflict versions stay for the user to resolve; the edit goes into the current file.
            var hadConflict = ubiquity.hasConflicts(url)
            if let seen = seenModification[task.id.relativePath], let current = fileSystem.modificationDate(of: url),
               abs(current.timeIntervalSince(seen)) > 0.001 {
                hadConflict = true
            }
            let file = try fileSystem.read(url)
            var document: FrontmatterDocument
            do {
                document = try FrontmatterDocument(text: file.text)
            } catch {
                throw TaskStoreError.brokenFrontmatter(task.name)
            }
            let clashing = hadConflict
                ? TaskConflicts.fields(changes, seen: task, latest: reader.task(from: document, name: task.name, relativePath: task.id.relativePath))
                : []
            let text = transform(&document)
            // Never write a note that would no longer parse.
            guard let updated = try? FrontmatterDocument(text: text) else { throw TaskStoreError.brokenFrontmatter(task.name) }
            try fileSystem.write(text, to: url)
            guard fileSystem.isWritten(text, at: url) else { throw TaskStoreError.notConfirmed(task.name) }
            seenModification[task.id.relativePath] = fileSystem.modificationDate(of: url)
            return TaskWriteResult(task: reader.task(from: updated, name: task.name, relativePath: task.id.relativePath),
                                   hadConflict: hadConflict, clashingFields: clashing)
        }
    }

    /// Name check that also sees evicted iCloud files (`.Name.md.icloud`).
    private func existingURL(of task: TaskItem, root: URL) throws -> URL {
        let url = root.appendingPathComponent(task.id.relativePath)
        guard fileSystem.fileExists(url) else { throw TaskStoreError.fileMissing(task.name) }
        return url
    }
}
