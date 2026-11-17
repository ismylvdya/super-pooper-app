import Foundation

/// The tasks' one file, as a person would keep them by hand: `Task Manager/Tasks.md` in the chosen folder, a line per task
/// under the section of its planning level (`TaskDocument`), and a JSON file per habit (`HabitFile`), whose days are its
/// lines in Done. Every write reads the file as it is now, changes only the item's own lines and writes it atomically, so
/// what was edited elsewhere stays. A line says whether it is in today's pool and in which section (`TodayPool`); what a
/// line cannot say (today's order and worms) the app keeps, and the habits' lines of today come to the file through
/// `mirror`. The rest of what the store does is in `TaskFileStore+Items`.
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
        let text = fileSystem.fileExists(url) ? try fileSystem.read(url).text : nil
        // The pool's older hashtags (`#in_today_pool`…) are written as the swimmer's marks with this read's write: the file
        // as it was is kept first.
        if let text, format.hasLegacyPoolMarks(text) {
            _ = try? backups.backup([url], reason: "poolmarks")
        }
        var document = text.map { TaskDocument(text: $0, format: format) } ?? TaskDocument(format: format)
        // Done has a file of its own; lines an older tasks file still has there come first, and leave it with the next write.
        let done = doneURL(root: root)
        try await ensureDownloaded(done)
        if fileSystem.fileExists(done) { document.takeDone(of: TaskDocument(text: try fileSystem.read(done).text, format: format)) }
        // An older file's Today joins Next actions once, with a backup of the file as it was (`takeTodaySections`).
        if document.hadTodaySection {
            _ = try? backups.backup([url, done].filter(fileSystem.fileExists), reason: "format3")
            document.hadTodaySection = false
        }
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
            makeListsProjects(&snapshot, root: root)
            makeSubhabitsTasks(&snapshot, root: root)
            _ = normalize(&snapshot)
            // Also when nothing changed but how the file says it (an older title, a field no longer kept).
            try write(snapshot.document, root: root)
            snapshot.indexNames()
            return VaultScanResult(tasks: items(of: snapshot), fileProblems: [], conflicted: [])
        }
    }

    /// An older file's own lists become projects, once, with a backup of the file as it was (`makeHeadingsProjects`).
    private func makeListsProjects(_ snapshot: inout Snapshot, root: URL) {
        let before = snapshot
        var document = snapshot.document
        guard document.makeHeadingsProjects(isTaken: { before.isTaken($0) }) else { return }
        let files = [fileURL(root: root), doneURL(root: root)].filter(fileSystem.fileExists)
        _ = try? backups.backup(files, reason: "projects")
        snapshot.document = document
    }

    /// Tasks and habits as the app knows them: what is put away in Done or the trash is left out. Each takes the place of
    /// its line among the file's lines (`storeOrder`), a habit that of its open line: the pool's order (D-180).
    func items(of snapshot: Snapshot) -> [TaskItem] {
        var tasks: [TaskItem] = []
        var habitLines: [String: Int] = [:]
        var place = 0
        snapshot.document.walk { entry, section, parent, index in
            guard section != .done, section != .trash, let id = entry.id else { return }
            place += 1
            guard snapshot.habits[id] == nil else {
                if entry.completed == nil, habitLines[id] == nil { habitLines[id] = place }
                return
            }
            var task = item(entry, in: section, parent: parent, index: index, snapshot: snapshot)
            task.storeOrder = place
            tasks.append(task)
        }
        return tasks + snapshot.habits.values.map { file in
            var habit = habit(of: file, snapshot: snapshot)
            habit.storeOrder = habitLines[file.id]
            return habit
        }
    }

    /// The place of the open line of `id` among the file's lines, as `items` counts them.
    func storeOrder(of id: String, in snapshot: Snapshot) -> Int? {
        var place = 0
        var found: Int?
        snapshot.document.walk { entry, section, _, _ in
            guard found == nil, section != .done, section != .trash, let own = entry.id else { return }
            place += 1
            if own == id, entry.completed == nil { found = place }
        }
        return found
    }

    func item(_ entry: TaskEntry, in section: TaskSection, parent: TaskEntry?, index: Int, snapshot: Snapshot) -> TaskItem {
        let parentName = parent?.name ?? entry.parent.flatMap { snapshot.names[$0] }
        return entry.item(in: section, parentName: parentName, order: parent == nil ? nil : index, follows: parent.flatMap(logicalDay(of:)), format: format)
    }

    func habit(of file: HabitFile, snapshot: Snapshot) -> TaskItem {
        var item = file.item(parentName: file.parent.flatMap { snapshot.names[$0] }, marks: snapshot.document.marks(of: file.id))
        let line = snapshot.document.openLine(of: file.id)
        item.isOverdue = line?.isOverdue == true && line?.date == today()
        item.nextLine = line?.date.map { TaskDue(day: $0, time: line?.time) }
        return item
    }

    /// What a day's turn or a hand in Obsidian leaves to tidy: a habit's line ticked in Next actions is its mark, a habit's
    /// line carries no tag of the pool, and a file about another day has its day turned (`turnDay`). True when something
    /// changed.
    func normalize(_ snapshot: inout Snapshot) -> Bool {
        let before = snapshot.document
        let day = today()
        let habits = Set(snapshot.habits.keys)
        var ticked: [String] = []
        snapshot.document.walk { entry, section, _, _ in
            if let id = entry.id, habits.contains(id), section == .soon, entry.box != .open, entry.completed == nil { ticked.append(id) }
        }
        for id in ticked {
            guard let taken = removeHabitLine(id, from: &snapshot.document), let name = snapshot.habits[id]?.name else { continue }
            snapshot.document.setMark(taken.box == .done ? .done : .partial, on: day, habit: id, name: name)
        }
        snapshot.document.forEachOpenLine { entry, _ in
            if entry.id.map(habits.contains) ?? false {
                entry.inTodayPool = false
                entry.poolSection = nil
            }
        }
        if !snapshot.document.prelude.contains(dayMarker) {
            turnDay(&snapshot, to: day)
            setDayMarker(in: &snapshot.document)
        }
        gatherSubtasks(&snapshot.document, habits: habits)
        carryMissedHabits(&snapshot, to: day)
        return snapshot.document != before
    }

    /// The logical day a line stands on.
    func logicalDay(of entry: TaskEntry) -> LocalDate? {
        entry.date.map { TaskDue(day: $0, time: entry.time).logicalDay(boundary: boundary()) }
    }

    /// A new day (the file's day marker names another one, or none): every task leaves today's pool and the sections
    /// that do not last (`format.pool.lastingSections`), and the day's turn puts back in the pool what is due
    /// (`TodayPool.dayTurn`). A date that has passed stays — it is a deadline — and its line is marked overdue; the
    /// time it was meant for has passed with its day, so it goes (with its zone and its notification).
    private func turnDay(_ snapshot: inout Snapshot, to day: LocalDate) {
        let habits = Set(snapshot.habits.keys)
        let lasting = Set(format.pool.lastingSections)
        snapshot.document.forEachOpenLine { entry, section in
            guard !(entry.id.map(habits.contains) ?? false), section != .archive else { return }
            entry.inTodayPool = false
            if let word = entry.poolSection, !lasting.contains(word) { entry.poolSection = nil }
            guard entry.box != .done, let date = logicalDay(of: entry), date < day else { return }
            entry.isOverdue = true
            entry.time = nil
            entry.zone = nil
            entry.alarm = nil
        }
        snapshot.indexNames()
        let items = items(of: snapshot)
        let due = TodayPool.dayTurn(items, today: day, boundary: boundary())
        for item in items where due.contains(item.name) {
            snapshot.document.update(id: item.id.value) { $0.inTodayPool = true }
            // The pool is Next actions': a task of Soon or Someday due today moves there, naming its parent if it had one.
            guard !item.status.isThisWeek, let place = place(of: item.id.value, in: snapshot.document),
                  var taken = snapshot.document.remove(where: { $0.id == item.id.value })?.entry else { continue }
            taken.parent = place.parent ?? place.tag
            snapshot.document.insert(taken, into: .soon)
        }
        // What the review planned yesterday kept out of today has stayed out: its mark goes.
        snapshot.document.forEachOpenLine { entry, _ in entry.notTomorrow = false }
    }

    nonisolated func nameProblem(in name: String) -> NoteNameProblem? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .empty }
        if name != name.trimmingCharacters(in: .whitespacesAndNewlines) { return .spacesAround }
        if let marker = (format.markers.all + [format.pool.marker]).first(where: name.contains), let symbol = marker.first { return .forbidden(symbol) }
        return name.first(where: \.isNewline).map(NoteNameProblem.forbidden)
    }
}
