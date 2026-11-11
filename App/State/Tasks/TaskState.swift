import Foundation
import Observation

enum VaultState: Equatable {
    case notSelected
    case ready
    case failed(AppFailure)
}

/// The tasks and habits as the store last gave them and the app changed them since, with the problems found reading
/// them, the notes in conflict, the filed tasks and what the chosen folder is. A scan that ran while the app wrote
/// keeps what was written meanwhile.
@MainActor
@Observable
final class TaskState {
    private(set) var tasks: [TaskItem] = []
    /// The tasks the store filed away, read when the Lists tab or the Done list shows.
    private(set) var filedTasks: [TaskItem] = []
    private(set) var fileProblems: [FileProblem] = []
    /// Notes with conflicting versions the user has not resolved yet.
    private(set) var conflictedNotes: [String] = []
    /// What the chosen folder is (the tasks' folder or a whole vault) and where it is in Obsidian, where the store says.
    private(set) var chosenFolder = ChosenFolder()
    private(set) var vaultState: VaultState = .notSelected
    /// Notes written while a scan was running; their scanned copies are stale.
    @ObservationIgnored private var writtenDuringSync: Set<TaskID>?
    /// Notes trashed or renamed away while a sync runs (its scan may still list them).
    @ObservationIgnored private var removedDuringSync: Set<TaskID>?

    func task(named name: String) -> TaskItem? { tasks.first { $0.name.isSameNoteName(as: name) } }

    /// Subtasks of a note (notes whose `projects` link to it), in their order.
    func subtasks(of parent: String) -> [TaskItem] {
        SubtaskOrder.sorted(tasks.filter { $0.projects.contains { $0.isSameNoteName(as: parent) } })
    }

    func replace(_ task: TaskItem) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            // A line written keeps its place among the lines (only a read of the file says it).
            var kept = task
            kept.storeOrder = task.storeOrder ?? tasks[index].storeOrder
            tasks[index] = kept
        } else {
            tasks.append(task)
        }
    }

    /// Where the habits' lines stand in the file now.
    func setNextLines(_ lines: [TaskID: TaskDue]) {
        for index in tasks.indices where tasks[index].isHabit && tasks[index].nextLine != lines[tasks[index].id] {
            tasks[index].nextLine = lines[tasks[index].id]
        }
    }

    /// A note the app just wrote: shown at once, and kept over a scan that is still running.
    func written(_ task: TaskItem) {
        writtenDuringSync?.insert(task.id)
        replace(task)
    }

    func remove(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
        removedDuringSync?.insert(task.id)
    }

    /// Notes written while the scan ran keep their in-memory version, and notes created or renamed meanwhile
    /// (the scan had listed the files before them) are kept too.
    func setScanResult(_ result: VaultScanResult) {
        let freshlyWritten = writtenDuringSync ?? []
        let removed = removedDuringSync ?? []
        let scanned = Set(result.tasks.map(\.id))
        let newer = tasks.filter { freshlyWritten.contains($0.id) && !scanned.contains($0.id) }
        tasks = result.tasks.filter { !removed.contains($0.id) }.map { scanned in
            freshlyWritten.contains(scanned.id) ? (tasks.first { $0.id == scanned.id } ?? scanned) : scanned
        } + newer
        fileProblems = result.fileProblems
        conflictedNotes = result.conflicted
        vaultState = .ready
    }


    /// Whatever a change did, the files are the truth: they are read again (a failed read keeps what is shown).
    func reload(from store: TaskStore) async {
        if let result = try? await store.load() { setScanResult(result) }
    }

    func beginTrackingWrites() {
        writtenDuringSync = []
        removedDuringSync = []
    }

    func endTrackingWrites() {
        writtenDuringSync = nil
        removedDuringSync = nil
    }

    func setVaultState(_ state: VaultState) {
        vaultState = state
        if state != .ready {
            tasks = []
            fileProblems = []
        }
    }

    func setChosenFolder(_ folder: ChosenFolder) { chosenFolder = folder }
    func setFiled(_ tasks: [TaskItem]) { filedTasks = tasks }

    /// The Done list and its count see a task filed just now before the folder is read again.
    func addFiled(_ task: TaskItem) { filedTasks.append(task) }
    func filedTask(_ id: TaskID) -> TaskItem? { filedTasks.first { $0.id == id } }
    func removeFiled(_ task: TaskItem) { filedTasks.removeAll { $0.id == task.id } }
}
