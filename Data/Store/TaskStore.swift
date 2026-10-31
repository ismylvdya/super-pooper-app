import Foundation

/// A file-level problem found while loading the tasks.
enum FileProblem: Hashable, Sendable {
    case brokenYAML(file: String, error: FrontmatterError)
    case notDownloaded(file: String)
    case unreadable(file: String, reason: String)
    case tasksFolderMissing(String)
}

struct VaultScanResult: Sendable {
    var tasks: [TaskNote]
    var fileProblems: [FileProblem]
    /// Items with conflicting versions waiting for the user to pick one (names).
    var conflicted: [String]
}

struct TaskWriteResult: Sendable {
    let task: TaskNote
    /// The item changed elsewhere since it was read (or had conflicting versions); the edit was applied to the latest
    /// version.
    let hadConflict: Bool
    /// Keys this edit wrote that had also been changed elsewhere to something else (the edit won).
    var clashingKeys: [String] = []
}

enum TaskStoreError: Error, Equatable, Sendable {
    case fileMissing(String)
    case brokenFrontmatter(String)
    case invalidName(String)
    case nameTaken(String)
    /// The change was written, but what was read back does not show it: it does not count as made.
    case notConfirmed(String)
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
    func apply(_ changes: [TaskEdit], to task: TaskNote) async throws -> TaskWriteResult
    /// A new item with every field and the text of the draft. The name is made unique (`Name`, `Name 2`, …).
    func create(_ draft: NoteDraft, named name: String) async throws -> TaskNote
    /// Renames the item; the items that refer to it (`dependents`) are rewritten to refer to the new name.
    func rename(_ task: TaskNote, to newName: String, dependents: [TaskNote]) async throws -> TaskNote
    /// Deletes the item (into the store's trash, where it has one).
    func delete(_ task: TaskNote) async throws
    /// Puts a completed task away from the active ones; it is gone from `load` and listed by `filedTasks`.
    func fileAway(_ task: TaskNote) async throws
    /// The tasks put away, read-only.
    func filedTasks() async throws -> [TaskNote]
    /// The item's own text (the note body), without anything the app keeps in it for itself.
    func text(of task: TaskNote) async throws -> String
    func setText(_ text: String, of task: TaskNote) async throws -> TaskWriteResult
    /// What is wrong with `name` as the name of an item in this store; nil for a name it can take.
    func nameProblem(in name: String) -> NoteNameProblem?
}

/// Conflicting versions of an item (iCloud), and keeping the one the user picked.
protocol VersionConflictResolving: Sendable {
    func versions(of task: TaskNote) async throws -> [NoteVersion]
    func keep(_ versionID: String, of task: TaskNote) async throws
}

/// A link that opens an item in the app the store belongs to (Obsidian).
protocol ExternalLinking: Sendable {
    func externalURL(for task: TaskNote) async -> URL?
}

/// Copies of items taken before risky changes (rename, delete, mass status changes).
protocol TaskBackups: Sendable {
    func backup(_ tasks: [TaskNote], reason: String) async throws
}

/// What the folder chosen for the store is: the tasks' own folder or a whole vault, and where it is in Obsidian.
protocol FolderInspecting: Sendable {
    func chosenFolder() async -> ChosenFolder
}
