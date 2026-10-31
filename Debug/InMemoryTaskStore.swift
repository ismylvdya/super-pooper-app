#if DEBUG
import Foundation

/// Task notes in memory for previews and tests of the app state.
actor InMemoryTaskStore: TaskStore, VersionConflictResolving, ExternalLinking, TaskBackups, FolderInspecting {
    /// Notes moved to the done folder.
    private var filed: [TaskNote] = []
    private var tasks: [TaskNote]
    private var bodies: [String: String] = [:]
    /// Texts that cannot be read (not downloaded, broken YAML), and every text written, in order.
    private var unreadableBodies: Set<String> = []
    private(set) var bodyWrites: [String] = []
    /// Scans throw this (tests of a vault that cannot be read).
    private var scanError: Error?
    /// Scans wait here after listing the notes until the test opens it (tests of work that overlaps a sync); how many ran.
    private var scanGate: AsyncGate?
    private(set) var scanCount = 0

    init(tasks: [TaskNote]) { self.tasks = tasks }

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

    func apply(_ changes: [TaskEdit], to task: TaskNote) async throws -> TaskWriteResult {
        let updated = task.applying(changes)
        tasks = tasks.map { $0.name == task.name ? updated : $0 }
        return TaskWriteResult(task: updated, hadConflict: false)
    }

    func text(of task: TaskNote) async throws -> String {
        guard !unreadableBodies.contains(task.name) else { throw CocoaError(.fileReadCorruptFile) }
        return bodies[task.name] ?? "Заметка к задаче."
    }

    func setText(_ body: String, of task: TaskNote) async throws -> TaskWriteResult {
        bodies[task.name] = body
        bodyWrites.append(body)
        return TaskWriteResult(task: task, hadConflict: false)
    }

    func rename(_ task: TaskNote, to newName: String, dependents: [TaskNote]) async throws -> TaskNote {
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

    func delete(_ task: TaskNote) async throws { tasks.removeAll { $0.name == task.name } }
    func fileAway(_ task: TaskNote) async throws {
        tasks.removeAll { $0.name == task.name }
        filed.append(task)
    }
    func filedTasks() async throws -> [TaskNote] { filed }
    func backup(_ tasks: [TaskNote], reason: String) async throws {}

    func create(_ draft: NoteDraft, named name: String) async throws -> TaskNote {
        var task = draft.note
        task.name = name
        task.id = TaskID("TaskNotes/Tasks/\(name).md")
        tasks.append(task)
        if !draft.body.isEmpty { bodies[name] = draft.body }
        return task
    }
    nonisolated func nameProblem(in name: String) -> NoteNameProblem? { NoteNameRules.problem(in: name) }
    func externalURL(for task: TaskNote) async -> URL? { nil }
    func chosenFolder() async -> ChosenFolder { ChosenFolder() }
    func versions(of task: TaskNote) async throws -> [NoteVersion] { [] }
    func keep(_ versionID: String, of task: TaskNote) async throws {}
}
#endif
