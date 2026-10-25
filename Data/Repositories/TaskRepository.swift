import Foundation

/// A file-level problem found while scanning the vault.
enum FileProblem: Hashable, Sendable {
    case brokenYAML(file: String, reason: String)
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
    /// A new note in the tasks folder, written the way TaskNotes writes it. The name is made unique
    /// (`Name`, `Name 2`, …).
    func create(named name: String, status: TaskStatus) async throws -> TaskNote
    func backup(_ tasks: [TaskNote], reason: String) async throws
    func obsidianURL(for task: TaskNote) async -> URL?
    /// iCloud conflict versions of a note, and keeping the one the user picked.
    func versions(of task: TaskNote) async throws -> [NoteVersion]
    func keep(_ versionID: String, of task: TaskNote) async throws
    /// The chosen folder is a whole vault (older setups) instead of the TaskNotes folder.
    func isWholeVault() async -> Bool
}
