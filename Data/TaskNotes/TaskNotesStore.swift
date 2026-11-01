import Foundation

/// The TaskNotes store: one note per task in the vault's tasks folder, its fields in YAML frontmatter as TaskNotes
/// writes them. Every write is coordinated and atomic, changes exactly the keys it was asked to, and is applied to the
/// latest file version ("last edit wins"). Moving notes between folders is in `TaskNotesStore+Folders`, the optional
/// capabilities (iCloud versions, Obsidian links, backups, the chosen folder) in `TaskNotesStore+Vault`.
actor TaskNotesStore: TaskStore {
    let location: VaultLocating
    let fileSystem: NoteFileSystem
    let folders: TaskNotesFolders
    let scanner: @Sendable (AppSettings.Vault) -> VaultScanner
    let vaultSettings: @Sendable () -> AppSettings.Vault
    let backups: BackupService
    let ubiquity: UbiquityService
    let noteExtension: String
    let obsidian: ObsidianConventions
    let names: ObsidianNoteNames
    let doneFolder: String
    /// A modification date further than this from the one seen means an edit elsewhere.
    let modificationTolerance: TimeInterval
    private let writer: TaskNoteWriter
    private let readerFactory: @Sendable (AppSettings.Vault) -> TaskNoteReader
    private let clock: Clock
    /// The modification date of each note as the store last read or wrote it: a different one means an edit elsewhere.
    var seenModification: [String: Date] = [:]

    init(location: VaultLocating, fileSystem: NoteFileSystem, ubiquity: UbiquityService, mapping: FieldMapping,
         calendar: CalendarSource, rules: RulesConfig.Vault, backups: BackupService, clock: Clock,
         vaultSettings: @escaping @Sendable () -> AppSettings.Vault) {
        self.location = location
        self.fileSystem = fileSystem
        self.ubiquity = ubiquity
        self.writer = TaskNoteWriter(mapping: mapping, calendar: calendar)
        self.folders = TaskNotesFolders(fileSystem: fileSystem, noteExtension: mapping.obsidian.noteExtension)
        let readerFactory: @Sendable (AppSettings.Vault) -> TaskNoteReader = {
            TaskNoteReader(mapping: mapping, taskTag: $0.taskTag, calendar: calendar.current)
        }
        self.readerFactory = readerFactory
        self.scanner = { settings in
            VaultScanner(fileSystem: fileSystem, ubiquity: ubiquity, reader: readerFactory(settings),
                         noteExtension: mapping.obsidian.noteExtension, downloadTimeout: rules.downloadTimeoutSeconds,
                         downloadPoll: rules.downloadPollSeconds)
        }
        self.vaultSettings = vaultSettings
        self.backups = backups
        self.clock = clock
        self.noteExtension = mapping.obsidian.noteExtension
        self.obsidian = mapping.obsidian
        self.names = ObsidianNoteNames(rules: mapping.obsidian.noteNames)
        self.doneFolder = rules.doneFolder
        self.modificationTolerance = rules.modificationToleranceSeconds
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
        guard names.isValid(newName) else { throw TaskStoreError.invalidName(newName) }
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
        names.problem(in: name)
    }

    private func createNote(named name: String, status: TaskStatus) async throws -> TaskItem {
        guard names.isValid(name) else { throw TaskStoreError.invalidName(name) }
        let settings = vaultSettings()
        let reader = readerFactory(settings)
        let text = writer.newNote(tag: settings.taskTag, status: status, now: clock.now)
        return try await location.withRoot { root in
            let folder = folders.tasks(settings, root: root)
            let (finalName, url) = folders.freeFile(for: name, in: folder)
            try fileSystem.createFolder(folder)
            try fileSystem.write(text, to: url)
            guard fileSystem.isWritten(text, at: url) else { throw TaskStoreError.notConfirmed(finalName) }
            let relativePath = VaultPaths.relative(url, to: root)
            seenModification[relativePath] = fileSystem.modificationDate(of: url)
            return reader.task(from: try FrontmatterDocument(text: text), name: finalName, relativePath: relativePath)
        }
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
               abs(current.timeIntervalSince(seen)) > modificationTolerance {
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
    func existingURL(of task: TaskItem, root: URL) throws -> URL {
        let url = root.appendingPathComponent(task.id.relativePath)
        guard fileSystem.fileExists(url) else { throw TaskStoreError.fileMissing(task.name) }
        return url
    }
}
