import Foundation

/// The tasks' one file, as a person would keep them by hand: `Task Manager/Tasks.md` in the chosen folder, a line per task
/// under the section of its planning level (`TaskDocument`), and a JSON file per habit (`HabitFile`), whose days are its
/// lines in Done. Every write reads the file as it is now, changes only the item's own lines and writes it atomically, so
/// what was edited elsewhere stays. What a line cannot say (today's order, sections and worms) the app keeps; its look
/// of today comes back to the file through `mirror`. The rest of what the store does is in `TaskFileStore+Items`.
actor TaskFileStore: TaskStore {
    struct Snapshot {
        var document: TaskDocument
        var habits: [String: HabitFile]
        var names: [String: String] = [:]

        /// Ids to names, for the links between items.
        mutating func indexNames() {
            names = habits.mapValues(\.name)
            document.walk { entry, _, _, _ in if let id = entry.id, habits[id] == nil { names[id] = entry.name } }
        }

        /// Every id a task or a habit goes by, and whether `name` is taken by another item than `except`.
        func isTaken(_ name: String, except id: String? = nil) -> Bool {
            names.contains { $0.key != id && $0.value.isSameNoteName(as: name) }
        }

        func id(ofName name: String) -> String? {
            names.first { $0.value.isSameNoteName(as: name) }?.key
        }
    }

    let location: VaultLocating
    let fileSystem: NoteFileSystem
    let ubiquity: UbiquityService
    let format: TaskFileFormat
    let obsidian: ObsidianConventions
    let backups: BackupService
    let vaultSettings: @Sendable () -> AppSettings.Vault
    let downloadTimeout: TimeInterval
    let downloadPoll: TimeInterval
    /// Today, logically: what has passed moves up to it.
    let today: @Sendable () -> LocalDate
    let makeID: @Sendable () -> String
    let lookMemory: DayLookMemory

    init(location: VaultLocating, fileSystem: NoteFileSystem, ubiquity: UbiquityService, format: TaskFileFormat,
         obsidian: ObsidianConventions, backups: BackupService, rules: RulesConfig.Vault,
         vaultSettings: @escaping @Sendable () -> AppSettings.Vault, today: @escaping @Sendable () -> LocalDate,
         lookMemory: DayLookMemory,
         makeID: @escaping @Sendable () -> String = { String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).lowercased() }) {
        self.location = location
        self.fileSystem = fileSystem
        self.ubiquity = ubiquity
        self.format = format
        self.obsidian = obsidian
        self.backups = backups
        self.vaultSettings = vaultSettings
        self.downloadTimeout = rules.downloadTimeoutSeconds
        self.downloadPoll = rules.downloadPollSeconds
        self.today = today
        self.makeID = makeID
        self.lookMemory = lookMemory
    }

    // MARK: - The files

    func fileURL(root: URL) -> URL {
        root.appendingPathComponent(format.folder, isDirectory: true).appendingPathComponent(format.file)
    }

    func habitsFolder(root: URL) -> URL {
        root.appendingPathComponent(format.folder, isDirectory: true).appendingPathComponent(format.habitsFolder, isDirectory: true)
    }

    func habitsTrash(root: URL) -> URL {
        habitsFolder(root: root).appendingPathComponent(format.habitsTrashFolder, isDirectory: true)
    }

    /// Reads the file and the habits as they are now. A file iCloud has not brought down yet is waited for: it is never
    /// taken for missing, which would write a new empty one over it.
    func read(root: URL) async throws -> Snapshot {
        let url = fileURL(root: root)
        // A folder chosen by mistake (or the old TaskNotes one) stays as it is: the app makes no folders of its own there.
        guard fileSystem.fileExists(url.deletingLastPathComponent()) else { throw TaskStoreError.folderMissing(format.folder) }
        try await ensureDownloaded(url)
        let document = fileSystem.fileExists(url)
            ? TaskDocument(text: try fileSystem.read(url).text, format: format)
            : TaskDocument(format: format)
        var snapshot = Snapshot(document: document, habits: try await readHabits(root: root))
        snapshot.indexNames()
        return snapshot
    }

    private func readHabits(root: URL) async throws -> [String: HabitFile] {
        let folder = habitsFolder(root: root)
        guard fileSystem.fileExists(folder) else { return [:] }
        var habits: [String: HabitFile] = [:]
        for url in try fileSystem.contents(of: folder) where url.lastPathComponent.contains(".json") {
            let name = url.lastPathComponent
            // iCloud keeps a file not brought down yet as `.name.json.icloud`.
            let real = name.hasPrefix(".") ? folder.appendingPathComponent(String(name.dropFirst()).replacingOccurrences(of: ".icloud", with: "")) : url
            try await ensureDownloaded(real)
            guard let data = try fileSystem.read(real).text.data(using: .utf8),
                  let habit = try? JSONDecoder().decode(HabitFile.self, from: data) else { continue }
            habits[habit.id] = habit
        }
        return habits
    }

    /// iCloud may keep a file not brought down as a placeholder beside it (`.name.icloud`) or as a file without its data.
    private func ensureDownloaded(_ url: URL) async throws {
        let placeholder = url.deletingLastPathComponent().appendingPathComponent("." + url.lastPathComponent + ".icloud")
        let isHere = { [fileSystem, ubiquity] in !fileSystem.fileExists(placeholder) && ubiquity.isDownloaded(url) }
        guard !isHere() else { return }
        try? ubiquity.startDownloading(url)
        let deadline = Date().addingTimeInterval(downloadTimeout)
        while !isHere() {
            guard Date() < deadline else { throw TaskStoreError.notDownloaded(url.lastPathComponent) }
            try await Task.sleep(for: .seconds(downloadPoll))
        }
    }

    /// Writes the file when it changed; what was written is read back before it counts.
    func write(_ document: TaskDocument, root: URL) throws {
        let url = fileURL(root: root)
        let text = document.text(format: format)
        if fileSystem.fileExists(url), (try? fileSystem.read(url).text) == text { return }
        try fileSystem.write(text, to: url)
        guard fileSystem.isWritten(text, at: url) else { throw TaskStoreError.notConfirmed(format.file) }
    }

    func write(_ habit: HabitFile, root: URL) throws {
        let folder = habitsFolder(root: root)
        try fileSystem.createFolder(folder)
        let url = folder.appendingPathComponent(habit.id + ".json")
        let text = try habit.text()
        try fileSystem.write(text, to: url)
        guard fileSystem.isWritten(text, at: url) else { throw TaskStoreError.notConfirmed(habit.name) }
    }

    // MARK: - Reading

    func load() async throws -> VaultScanResult {
        try await location.withRoot { root in
            var snapshot: Snapshot
            do {
                snapshot = try await read(root: root)
            } catch TaskStoreError.notDownloaded(let file) {
                return VaultScanResult(tasks: [], fileProblems: [.notDownloaded(file: file)], conflicted: [])
            } catch TaskStoreError.folderMissing(let folder) {
                return VaultScanResult(tasks: [], fileProblems: [.tasksFolderMissing(folder)], conflicted: [])
            }
            if normalize(&snapshot) { try write(snapshot.document, root: root) }
            snapshot.indexNames()
            return VaultScanResult(tasks: items(of: snapshot), fileProblems: [], conflicted: [])
        }
    }

    /// Tasks and habits as the app knows them: what is put away in Done or the trash is left out, and so are the lines a
    /// habit has in today's sections (only a look of the day).
    func items(of snapshot: Snapshot) -> [TaskItem] {
        var tasks: [TaskItem] = []
        snapshot.document.walk { entry, section, parent, index in
            guard section != .done, section != .trash, let id = entry.id, snapshot.habits[id] == nil else { return }
            tasks.append(item(entry, in: section, parent: parent, index: index, snapshot: snapshot))
        }
        return tasks + snapshot.habits.values.map { habit(of: $0, snapshot: snapshot) }
    }

    func item(_ entry: TaskEntry, in section: TaskSection, parent: TaskEntry?, index: Int, snapshot: Snapshot) -> TaskItem {
        let parentName = parent?.name ?? entry.parent.flatMap { snapshot.names[$0] }
        return entry.item(in: section, parentName: parentName, order: parent == nil ? nil : index)
    }

    func habit(of file: HabitFile, snapshot: Snapshot) -> TaskItem {
        file.item(parentName: file.parent.flatMap { snapshot.names[$0] }, marks: snapshot.document.marks(of: file.id))
    }

    /// What a day's turn or a hand in Obsidian leaves to tidy: lines without an id get one; a task dated before today
    /// comes up to today with its time, a task whose day has come moves from Soon to Now; a habit's line ticked in today's
    /// sections is its mark. True when something changed.
    func normalize(_ snapshot: inout Snapshot) -> Bool {
        let before = snapshot.document
        let day = today()
        func assignIDs(_ entries: inout [TaskEntry]) {
            for index in entries.indices {
                if entries[index].id == nil { entries[index].id = makeID() }
                assignIDs(&entries[index].children)
            }
        }
        for section in snapshot.document.sections.indices where snapshot.document.sections[section].kind != nil {
            for group in snapshot.document.sections[section].groups.indices {
                assignIDs(&snapshot.document.sections[section].groups[group].entries)
            }
        }
        // Ticked habit lines and Soon's lines whose day has come leave their sections.
        var moves: [(id: String, habit: Bool)] = []
        snapshot.document.walk { entry, section, parent, _ in
            guard section == .now || section == .soon, let id = entry.id else { return }
            if snapshot.habits[id] != nil {
                if entry.box != .open { moves.append((id, true)) }
            } else if section == .soon, parent == nil, entry.box != .done, entry.date.map({ $0 <= day }) == true {
                moves.append((id, false))
            }
        }
        for move in moves {
            guard let taken = snapshot.document.remove(where: { $0.id == move.id && $0.completed == nil }) else { continue }
            if move.habit, let name = snapshot.habits[move.id]?.name {
                snapshot.document.setMark(taken.entry.box == .done ? .done : .partial, on: day, habit: move.id, name: name)
            } else {
                snapshot.document.insert(taken.entry, into: .now)
            }
        }
        rollOver(&snapshot.document, to: day)
        return snapshot.document != before
    }

    /// An open task's date that has passed becomes today's; its time stays.
    private func rollOver(_ document: inout TaskDocument, to day: LocalDate) {
        func roll(_ entries: inout [TaskEntry]) {
            for index in entries.indices {
                if entries[index].box != .done, let date = entries[index].date, date < day { entries[index].date = day }
                roll(&entries[index].children)
            }
        }
        for section in document.sections.indices where document.sections[section].kind == .now || document.sections[section].kind == .soon {
            for group in document.sections[section].groups.indices { roll(&document.sections[section].groups[group].entries) }
        }
    }

    nonisolated func nameProblem(in name: String) -> NoteNameProblem? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .empty }
        if name != name.trimmingCharacters(in: .whitespacesAndNewlines) { return .spacesAround }
        if let marker = format.markers.all.first(where: name.contains), let symbol = marker.first { return .forbidden(symbol) }
        return name.first(where: \.isNewline).map(NoteNameProblem.forbidden)
    }
}
