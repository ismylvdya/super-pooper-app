#if DEBUG
import Foundation

/// Task notes in memory for previews and tests of the app state.
actor InMemoryTaskStore: TaskStore, TaskTrash, VersionConflictResolving, ExternalLinking, TaskBackups, FolderInspecting {
    /// Notes moved to the done folder.
    private var filed: [TaskItem] = []
    /// Notes moved to the trash, by where they lie there.
    private var trashed: [String: TaskItem] = [:]
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
            updated.projects = rename(item.projects)
            return updated
        }
        return renamed
    }

    func delete(_ task: TaskItem) async throws -> TrashedNote? {
        tasks.removeAll { $0.id == task.id }
        filed.removeAll { $0.id == task.id }
        let note = TrashedNote(id: ".trash/\(task.name).md", name: task.name, trashedAt: nil)
        trashed[note.id] = task
        return note
    }

    func notes() async throws -> [TrashedNote] {
        trashed.map { TrashedNote(id: $0.key, name: $0.value.name, trashedAt: nil) }.sorted { $0.name < $1.name }
    }
    func text(of note: TrashedNote) async throws -> String { bodies[note.name] ?? "" }
    func restore(_ note: TrashedNote) async throws -> String {
        guard let task = trashed.removeValue(forKey: note.id) else { throw CocoaError(.fileNoSuchFile) }
        tasks.append(task)
        return task.name
    }
    func deletePermanently(_ note: TrashedNote) async throws { trashed[note.id] = nil }
    /// The note moves to the done folder, as in the vault: the id says so.
    func fileAway(_ task: TaskItem) async throws -> TaskItem {
        tasks.removeAll { $0.id == task.id }
        var moved = task
        moved.id = TaskID("TaskNotes/Done/\(task.name).md")
        filed.append(moved)
        return moved
    }
    func filedTasks() async throws -> [TaskItem] { filed }
    func unfile(_ task: TaskItem) async throws -> TaskItem {
        filed.removeAll { $0.id == task.id }
        var reopened = task.applying([.reopen])
        reopened.id = TaskID("TaskNotes/Tasks/\(task.name).md")
        tasks.append(reopened)
        return reopened
    }
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
