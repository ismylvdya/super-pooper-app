import Foundation

/// A file-level problem found while scanning the vault.
enum FileProblem: Hashable, Sendable {
    case brokenYAML(file: String, error: FrontmatterError)
    case notDownloaded(file: String)
    case unreadable(file: String, reason: String)
    case tasksFolderMissing(String)
}

struct VaultScanResult: Sendable {
    var tasks: [TaskNote]
    var fileProblems: [FileProblem]
    /// Notes with iCloud conflict versions waiting for the user to pick one (names).
    var conflicted: [String]
}

struct TaskWriteResult: Sendable {
    let task: TaskNote
    /// The file changed elsewhere since it was read (or had iCloud conflicts); the edit was
    /// applied to the latest version.
    let hadConflict: Bool
    /// Keys this edit wrote that had also been changed elsewhere to something else (the edit won).
    var clashingKeys: [String] = []
}

enum TaskRepositoryError: Error, Equatable, Sendable {
    case fileMissing(String)
    case brokenFrontmatter(String)
    case invalidName(String)
    case nameTaken(String)
    /// The change was written, but the file read back does not show it: it does not count as made.
    case notConfirmed(String)
}

/// Reads, edits and creates TaskNotes notes.
protocol TaskRepository: Sendable {
    func scan() async throws -> VaultScanResult
    func apply(_ changes: [TaskFieldChange], to task: TaskNote) async throws -> TaskWriteResult
    func body(of task: TaskNote) async throws -> String
    func setBody(_ body: String, of task: TaskNote) async throws -> TaskWriteResult
    /// Renames the file and rewrites `previous_task` links in `dependents`.
    func rename(_ task: TaskNote, to newName: String, dependents: [TaskNote]) async throws -> TaskNote
    /// Moves the note to the vault's `.trash` folder (Obsidian's trash).
    func moveToTrash(_ task: TaskNote) async throws
    /// Moves a done note into the done folder next to the tasks folder (`Name`, `Name 2`, … when taken there).
    func fileAway(_ task: TaskNote) async throws
    /// The notes in the done folder, read-only.
    func filedTasks() async throws -> [TaskNote]
    /// A new note in the tasks folder, written the way TaskNotes writes it. The name is made unique
    /// (`Name`, `Name 2`, …).
    func create(named name: String, status: TaskStatus) async throws -> TaskNote
    func backup(_ tasks: [TaskNote], reason: String) async throws
    func obsidianURL(for task: TaskNote) async -> URL?
    /// iCloud conflict versions of a note, and keeping the one the user picked.
    func versions(of task: TaskNote) async throws -> [NoteVersion]
    func keep(_ versionID: String, of task: TaskNote) async throws
    /// Whether the chosen folder is a whole vault (older setups) instead of the TaskNotes folder, and where it is in
    /// Obsidian.
    func chosenFolder() async -> ChosenFolder
}
