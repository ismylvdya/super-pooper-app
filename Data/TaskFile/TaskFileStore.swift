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

        /// Ids to names of what is open, for the links between items. What lies in Done or the trash is only a line: its
        /// name is free for a new task.
        mutating func indexNames() {
            names = habits.mapValues(\.name)
            document.walk { entry, section, _, _ in
                if let id = entry.id, habits[id] == nil, section != .done, section != .trash { names[id] = entry.name }
            }
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
    /// When a logical day starts: a line at 01:00 on the 5th still belongs to the 4th with a 04:00 boundary.
    let boundary: @Sendable () -> LocalTime
    let makeID: @Sendable () -> String
    let lookMemory: DayLookMemory

    init(location: VaultLocating, fileSystem: NoteFileSystem, ubiquity: UbiquityService, format: TaskFileFormat,
         obsidian: ObsidianConventions, backups: BackupService, rules: RulesConfig.Vault,
         vaultSettings: @escaping @Sendable () -> AppSettings.Vault, today: @escaping @Sendable () -> LocalDate,
         boundary: @escaping @Sendable () -> LocalTime = { .midnight }, lookMemory: DayLookMemory,
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
        self.boundary = boundary
        self.makeID = makeID
        self.lookMemory = lookMemory
    }

    // MARK: - The files

    func doneURL(root: URL) -> URL {
        fileURL(root: root).deletingLastPathComponent().appendingPathComponent(format.doneFile)
    }

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
        var document = fileSystem.fileExists(url)
            ? TaskDocument(text: try fileSystem.read(url).text, format: format)
            : TaskDocument(format: format)
        // Done has a file of its own; lines an older tasks file still has there come first, and leave it with the next write.
        let done = doneURL(root: root)
        try await ensureDownloaded(done)
        if fileSystem.fileExists(done) { document.takeDone(of: TaskDocument(text: try fileSystem.read(done).text, format: format)) }
        var snapshot = Snapshot(document: document, habits: try await readHabits(root: root))
        TaskLineIDs.assign(to: &snapshot.document, habits: Set(snapshot.habits.keys))
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
    /// Done first: a write cut short leaves a line in both files, never in neither.
    func write(_ document: TaskDocument, root: URL) throws {
        try write(document.doneText(format: format), to: doneURL(root: root), named: format.doneFile)
        try write(document.tasksText(format: format), to: fileURL(root: root), named: format.file)
    }

    private func write(_ text: String, to url: URL, named name: String) throws {
        if fileSystem.fileExists(url), (try? fileSystem.read(url).text) == text { return }
        try fileSystem.write(text, to: url)
        guard fileSystem.isWritten(text, at: url) else { throw TaskStoreError.notConfirmed(name) }
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
            _ = normalize(&snapshot)
            // Also when nothing changed but how the file says it (an older title, a field no longer kept).
            try write(snapshot.document, root: root)
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
            var task = item(entry, in: section, parent: parent, index: index, snapshot: snapshot)
            task.storeOrder = tasks.count
            tasks.append(task)
        }
        return tasks + snapshot.habits.values.map { habit(of: $0, snapshot: snapshot) }
    }

    func item(_ entry: TaskEntry, in section: TaskSection, parent: TaskEntry?, index: Int, snapshot: Snapshot) -> TaskItem {
        let parentName = parent?.name ?? entry.parent.flatMap { snapshot.names[$0] }
        return entry.item(in: section, parentName: parentName, order: parent == nil ? nil : index, format: format)
    }

    func habit(of file: HabitFile, snapshot: Snapshot) -> TaskItem {
        var item = file.item(parentName: file.parent.flatMap { snapshot.names[$0] }, marks: snapshot.document.marks(of: file.id))
        let line = snapshot.document.openLine(of: file.id)
        item.isOverdue = line?.isOverdue == true && line?.date == today()
        return item
    }

    /// What a day's turn or a hand in Obsidian leaves to tidy: a task dated before today
    /// comes up to today without its time, so it waits in the pool; a task whose day has come moves from Soon to Now; a habit's line ticked in today's
    /// sections is its mark. True when something changed.
    func normalize(_ snapshot: inout Snapshot) -> Bool {
        let before = snapshot.document
        let day = today()
        dateNextActions(&snapshot.document, to: day, habits: Set(snapshot.habits.keys))
        // Ticked habit lines and Soon's lines whose day has come leave their sections.
        var moves: [(id: String, habit: Bool)] = []
        snapshot.document.walk { entry, section, parent, _ in
            guard section == .now || section == .soon, let id = entry.id else { return }
            if snapshot.habits[id] != nil {
                if entry.box != .open { moves.append((id, true)) }
            } else if section == .soon, parent == nil, entry.box != .done, logicalDay(of: entry).map({ $0 <= day }) == true {
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
        rollOver(&snapshot.document, to: day, habits: Set(snapshot.habits.keys))
        dateLooseLines(&snapshot.document, to: day, habits: Set(snapshot.habits.keys))
        carryMissedHabits(&snapshot, to: day)
        return snapshot.document != before
    }

    /// The logical day a line stands on.
    func logicalDay(of entry: TaskEntry) -> LocalDate? {
        entry.date.map { TaskDue(day: $0, time: entry.time).logicalDay(boundary: boundary()) }
    }

    /// A new day takes every undated task of Next actions: it stands in today's pool and morning review, whether the review is
    /// gone through or not. Tomorrow in the review moves it on. Told by the file's day marker, which the day's first mirror
    /// renews, so a task added during the day waits for the next morning. A file with no marker says nothing about a day.
    private func dateNextActions(_ document: inout TaskDocument, to day: LocalDate, habits: Set<String>) {
        let hasMarker = document.prelude.contains { $0.hasPrefix(format.dayMarkerPrefix) && $0.hasSuffix(format.dayMarkerSuffix) }
        guard hasMarker, !document.prelude.contains(dayMarker), let list = document.sections.firstIndex(where: { $0.kind == .soon }) else { return }
        for group in document.sections[list].groups.indices {
            for index in document.sections[list].groups[group].entries.indices {
                let entry = document.sections[list].groups[group].entries[index]
                if entry.date == nil, entry.box != .done, !(entry.id.map(habits.contains) ?? false) {
                    document.sections[list].groups[group].entries[index].date = day
                }
            }
        }
    }

    /// Only a date puts a task in Today: an undated line there (from an older file, or typed in) is today's.
    private func dateLooseLines(_ document: inout TaskDocument, to day: LocalDate, habits: Set<String>) {
        guard let now = document.sections.firstIndex(where: { $0.kind == .now }) else { return }
        for group in document.sections[now].groups.indices {
            for index in document.sections[now].groups[group].entries.indices {
                let entry = document.sections[now].groups[group].entries[index]
                if entry.date == nil, entry.box != .done, !(entry.id.map(habits.contains) ?? false) {
                    document.sections[now].groups[group].entries[index].date = day
                }
            }
        }
    }

    /// An open task's date that has passed becomes today's. The time it was meant for has passed with its day, so it goes
    /// (with its zone and its notification), and the task stands in the pool.
    private func rollOver(_ document: inout TaskDocument, to day: LocalDate, habits: Set<String>) {
        func roll(_ entries: inout [TaskEntry]) {
            for index in entries.indices {
                // A habit's line has its own way (`carryMissedHabits`).
                if entries[index].box != .done, let date = entries[index].date, logicalDay(of: entries[index]) ?? date < day, !(entries[index].id.map(habits.contains) ?? false) {
                    // Only what had a time was missed; a line without one just waits on.
                    if entries[index].time != nil { entries[index].isOverdue = true }
                    entries[index].date = day
                    entries[index].time = nil
                    entries[index].zone = nil
                    entries[index].alarm = nil
                }
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
