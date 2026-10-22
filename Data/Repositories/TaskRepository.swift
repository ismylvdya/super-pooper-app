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
    /// Tasks whose iCloud conflict versions were resolved during the scan.
    var conflictsResolved: [String]
}

struct TaskWriteResult: Sendable {
    let task: TaskNote
    /// The file changed elsewhere since it was read (or had iCloud conflicts); the edit was
    /// applied to the latest version.
    let hadConflict: Bool
}

enum TaskRepositoryError: Error, Equatable, Sendable {
    case fileMissing(String)
    case notATask(String)
    case brokenFrontmatter(String)
    case invalidName(String)
    case nameTaken(String)
}

/// Reads and edits TaskNotes notes. The app never creates notes.
protocol TaskRepository: Sendable {
    func scan() async throws -> VaultScanResult
    func apply(_ changes: [TaskFieldChange], to task: TaskNote) async throws -> TaskWriteResult
    func body(of task: TaskNote) async throws -> String
    func setBody(_ body: String, of task: TaskNote) async throws -> TaskWriteResult
    /// Renames the file and rewrites `previous_task` links in `dependents`.
    func rename(_ task: TaskNote, to newName: String, dependents: [TaskNote]) async throws -> TaskNote
    /// Moves the note to the vault's `.trash` folder (Obsidian's trash).
    func moveToTrash(_ task: TaskNote) async throws
    func backup(_ tasks: [TaskNote], reason: String) async throws
    func obsidianURL(for task: TaskNote) async -> URL?
}
