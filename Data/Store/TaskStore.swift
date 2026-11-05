import Foundation

/// A file-level problem found while loading the tasks.
enum FileProblem: Hashable, Sendable {
    case brokenYAML(file: String, error: FrontmatterError)
    case notDownloaded(file: String)
    case unreadable(file: String, reason: String)
    case tasksFolderMissing(String)
}

struct VaultScanResult: Sendable {
    var tasks: [TaskItem]
    var fileProblems: [FileProblem]
    /// Items with conflicting versions waiting for the user to pick one (names).
    var conflicted: [String]
}

struct TaskWriteResult: Sendable {
    let task: TaskItem
    /// The item changed elsewhere since it was read (or had conflicting versions); the edit was applied to the latest
    /// version.
    let hadConflict: Bool
    /// Fields this edit wrote that had also been changed elsewhere to something else (the edit won).
    var clashingFields: [TaskField] = []
}

enum TaskStoreError: Error, Equatable, Sendable {
    case fileMissing(String)
    case brokenFrontmatter(String)
    case invalidName(String)
    case nameTaken(String)
    /// The change was written, but what was read back does not show it: it does not count as made.
    case notConfirmed(String)
    /// iCloud did not bring the file down in time; nothing was read or written.
    case notDownloaded(String)
    /// The chosen folder has no folder of the tasks: nothing is created, another folder must be chosen.
    case folderMissing(String)
}

/// Where the tasks and habits live. The app state talks only to this protocol, never to a storage format: a second
/// format is a new type conforming to it (and to the optional capabilities below it can offer), and the domain, the
/// app state and the screens stay as they are. Every write applies to the latest stored version of the item and changes
/// only what it was asked to.
protocol TaskStore: Sendable {
    /// Every task and habit, the problems found reading them, and the items with conflicting versions.
    func load() async throws -> VaultScanResult
    /// Writes `changes` onto the latest version of `task`, as the app saw it: what changed elsewhere meanwhile stays,
    /// and the fields changed on both sides are reported.
    func apply(_ changes: [TaskEdit], to task: TaskItem) async throws -> TaskWriteResult
    /// A new item with every field and the text of the draft. The name is made unique (`Name`, `Name 2`, …).
    func create(_ draft: NoteDraft, named name: String) async throws -> TaskItem
    /// Renames the item; the items that refer to it (`dependents`) are rewritten to refer to the new name.
    func rename(_ task: TaskItem, to newName: String, dependents: [TaskItem]) async throws -> TaskItem
    /// Deletes the item: into the store's trash, where it has one, and returns where it lies there (for Undo); nil when
    /// it is gone for good.
    @discardableResult
    func delete(_ task: TaskItem) async throws -> TrashedNote?
    /// Puts a completed task away from the active ones; it is gone from `load` and listed by `filedTasks`. Returns it as
    /// filed (its id, and its name where that was taken there, may change).
    @discardableResult
    func fileAway(_ task: TaskItem) async throws -> TaskItem
    /// The tasks put away.
    func filedTasks() async throws -> [TaskItem]
    /// Brings a task put away back among the active ones, reopened (`TaskEdit.reopen`): the reverse of `fileAway`. A
    /// name taken there meanwhile gets a number; the task is returned as it is now.
    func unfile(_ task: TaskItem) async throws -> TaskItem
    /// The item's own text (the note body), without anything the app keeps in it for itself.
    func text(of task: TaskItem) async throws -> String
    func setText(_ text: String, of task: TaskItem) async throws -> TaskWriteResult
    /// What is wrong with `name` as the name of an item in this store; nil for a name it can take.
    func nameProblem(in name: String) -> NoteNameProblem?
}

/// Conflicting versions of an item (iCloud), and keeping the one the user picked.
protocol VersionConflictResolving: Sendable {
    func versions(of task: TaskItem) async throws -> [NoteVersion]
    func keep(_ versionID: String, of task: TaskItem) async throws
}

/// A link that opens an item in the app the store belongs to (Obsidian).
protocol ExternalLinking: Sendable {
    func externalURL(for task: TaskItem) async -> URL?
}

/// Copies of items taken before risky changes (rename, delete, mass status changes).
protocol TaskBackups: Sendable {
    func backup(_ tasks: [TaskItem], reason: String) async throws
}

/// What the folder chosen for the store is: the tasks' own folder or a whole vault, and where it is in Obsidian.
protocol FolderInspecting: Sendable {
    func chosenFolder() async -> ChosenFolder
}

/// What the day shows, for a store that keeps its file looking as the app does: the pool's sections with their lines in
/// order, what stands on the timeline, and what was kept out of today. What comes back from the file is `DayLook`.
struct DayMirror: Equatable, Sendable {
    struct Section: Equatable, Sendable {
        let title: String
        let names: [String]
    }

    let sections: [Section]
    /// Items on today's timeline, with the time they stand at today.
    let timed: [String: LocalTime]
    /// Habits taken out of today: their lines go to the next day (`waitingHabitLines`).
    var skipped: [String] = []
}

/// A store whose lines have an order a person sets.
protocol TaskOrdering: Sendable {
    func reorder(_ ids: [TaskID]) async throws
}

/// Keeps the store's own look of today in step with the app's.
protocol DayMirroring: Sendable {
    func mirror(_ day: DayMirror) async
    /// Today's look in the file, when it was changed elsewhere since this device last saw it; nil otherwise.
    func changedLook() async -> DayLook?
    /// Today's look in the file as it is, when the file is about today: what its lines say about the habits' times.
    func currentLook() async -> DayLook?
    /// The app took `look` in: from now on it is not news.
    func accept(_ look: DayLook) async
    /// The look this device last saw; what a changed look is told from.
    func lastLook() async -> DayLook?
}

/// What this device last saw of today's look in the file. Losing it costs one read of the file's look as news.
protocol DayLookMemory: Sendable {
    func load() -> DayLook?
    func save(_ look: DayLook)
}

/// An item read elsewhere, to be taken into the store.
struct ImportedItem: Sendable {
    let item: TaskItem
    let text: String
    /// Put away as done.
    let isFiled: Bool
}

/// Takes in items from elsewhere; a name it already has is left as it is. Returns how many it took.
protocol TaskImporting: Sendable {
    func importItems(_ items: [ImportedItem]) async throws -> Int
}
