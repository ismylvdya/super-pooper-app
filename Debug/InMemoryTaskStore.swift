#if DEBUG
import Foundation

/// Task notes in memory for previews and tests of the app state.
actor InMemoryTaskStore: TaskStore, VersionConflictResolving, ExternalLinking, TaskBackups, FolderInspecting {
    /// Notes moved to the done folder.
    private var filed: [TaskItem] = []
    private var tasks: [TaskItem]
    private var bodies: [String: String] = [:]
    /// Texts that cannot be read (not downloaded, broken YAML), and every text written, in order.
    private var unreadableBodies: Set<String> = []
    private(set) var bodyWrites: [String] = []
    /// Scans throw this (tests of a vault that cannot be read).
    private var scanError: Error?
    /// Scans wait here after listing the notes until the test opens it (tests of work that overlaps a sync); how many ran.
    private var scanGate: AsyncGate?
    private(set) var scanCount = 0

    /// The names a note can take, as the TaskNotes store has them.
    private let names: ObsidianNoteNames

    init(tasks: [TaskItem], names: ObsidianNoteNames) {
        self.tasks = tasks
        self.names = names
    }

    func failScans(with error: Error?) { scanError = error }
    func setBodyReadable(_ readable: Bool, of name: String) {
        if readable { unreadableBodies.remove(name) } else { unreadableBodies.insert(name) }
    }
    func holdScans(at gate: AsyncGate) { scanGate = gate }

    /// Like the vault scanner, the list of notes is taken first and read later.
    func load() async throws -> VaultScanResult {
        scanCount += 1
        let listed = tasks
        await scanGate?.pass()
        if let scanError { throw scanError }
        return VaultScanResult(tasks: listed, fileProblems: [], conflicted: [])
    }

    func apply(_ changes: [TaskEdit], to task: TaskItem) async throws -> TaskWriteResult {
        let updated = task.applying(changes)
        tasks = tasks.map { $0.name == task.name ? updated : $0 }
        return TaskWriteResult(task: updated, hadConflict: false)
    }

    func text(of task: TaskItem) async throws -> String {
        guard !unreadableBodies.contains(task.name) else { throw CocoaError(.fileReadCorruptFile) }
        return bodies[task.name] ?? "Заметка к задаче."
    }

    func setText(_ body: String, of task: TaskItem) async throws -> TaskWriteResult {
        bodies[task.name] = body
        bodyWrites.append(body)
        return TaskWriteResult(task: task, hadConflict: false)
    }

    func rename(_ task: TaskItem, to newName: String, dependents: [TaskItem]) async throws -> TaskItem {
        var renamed = task
        renamed.name = newName
        let rename = { (names: [String]) in NameReferences.renaming(names, from: task.name, to: newName) }
        tasks = tasks.map { item in
            guard item.name != task.name else { return renamed }
            var updated = item
            updated.previousTasks = rename(item.previousTasks)
            updated.projects = rename(item.projects)
            return updated
        }
        return renamed
    }

    func delete(_ task: TaskItem) async throws { tasks.removeAll { $0.name == task.name } }
    func fileAway(_ task: TaskItem) async throws {
        tasks.removeAll { $0.name == task.name }
        filed.append(task)
    }
    func filedTasks() async throws -> [TaskItem] { filed }
    func backup(_ tasks: [TaskItem], reason: String) async throws {}

    func create(_ draft: NoteDraft, named name: String) async throws -> TaskItem {
        var task = draft.note
        task.name = name
        task.id = TaskID("TaskNotes/Tasks/\(name).md")
        tasks.append(task)
        if !draft.body.isEmpty { bodies[name] = draft.body }
        return task
    }
    nonisolated func nameProblem(in name: String) -> NoteNameProblem? { names.problem(in: name) }
    func externalURL(for task: TaskItem) async -> URL? { nil }
    func chosenFolder() async -> ChosenFolder { ChosenFolder() }
    func versions(of task: TaskItem) async throws -> [NoteVersion] { [] }
    func keep(_ versionID: String, of task: TaskItem) async throws {}
}
#endif
