import Foundation

/// Every edit of a task's or habit's fields goes through here. The edits of one note run one after another, and each
/// decides from the note as the edit before it left it: a second quick tap (a toggle, a habit mark) does not repeat the
/// first one's decision. After a write the fields changed in two places are reported, a task written done takes its open
/// subtasks along (`SubtaskCascade`), the widgets and notifications follow, and what is done is filed away.
@MainActor
final class NoteWriter {
    private let tasks: TaskState
    private let store: TaskStore
    private let day: DayStateController
    private let derived: DerivedStatePublisher
    private let backups: BackupPolicy
    private let appEvents: AppEventSink
    private let filesDoneTasks: Bool
    /// The edit of each note still running.
    private var pendingEdits: [String: Task<Void, Never>] = [:]
    /// What filing made of each note, by its id before (Undo brings a task done a moment ago back).
    private var filedFrom: [TaskID: TaskItem] = [:]

    init(tasks: TaskState, store: TaskStore, day: DayStateController, derived: DerivedStatePublisher, backups: BackupPolicy,
         appEvents: AppEventSink, filesDoneTasks: Bool) {
        self.tasks = tasks
        self.store = store
        self.day = day
        self.derived = derived
        self.backups = backups
        self.appEvents = appEvents
        self.filesDoneTasks = filesDoneTasks
    }

    func edit(_ name: String, _ changes: @escaping (TaskItem) -> [TaskEdit]) async {
        let edit = enqueueEdit(name, changes)
        await edit.value
        if pendingEdits[name] == edit { pendingEdits[name] = nil }
    }

    /// The edit takes its place in the note's line at once and runs when the edits before it are done.
    @discardableResult
    func enqueueEdit(_ name: String, _ changes: @escaping (TaskItem) -> [TaskEdit]) -> Task<Void, Never> {
        let previous = pendingEdits[name]
        let edit = Task { @MainActor in
            await previous?.value
            guard let note = self.tasks.task(named: name) else { return }
            await self.write(note, changes(note))
        }
        pendingEdits[name] = edit
        return edit
    }

    /// Returns when the edits of the note asked for so far are written.
    func waitForEdits(of name: String) async {
        await pendingEdits[name]?.value
    }

    /// `cascades`: a task written done takes its open subtasks along; Undo, which puts back what was, does not.
    @discardableResult
    func write(_ task: TaskItem, _ changes: [TaskEdit], cascades: Bool = true) async -> Bool {
        guard !changes.isEmpty else { return true }
        guard let written = await apply(changes, to: task) else { return false }
        if cascades, task.status != .done, written.status == .done, !written.isHabit { await completeSubtasks(of: written) }
        await derived.publish()
        if DoneFiling.isDue(written) { await fileAwayDoneTasks() }
        return true
    }

    @discardableResult
    private func apply(_ changes: [TaskEdit], to task: TaskItem) async -> TaskItem? {
        do {
            let result = try await store.apply(changes, to: task)
            tasks.written(result.task)
            if let clashes = AppEvent.clashes(in: result, of: task.name) { appEvents.send(clashes) }
            return result.task
        } catch {
            appEvents.send(.failure(AppFailure(error)))
            return nil
        }
    }

    /// A task just completed takes its open subtasks along, all the way down, done the same day; reopening it later
    /// leaves them done.
    private func completeSubtasks(of parent: TaskItem) async {
        let marking = TaskMarking(today: day.context().today)
        for subtask in SubtaskCascade.subtasks(of: parent, in: tasks.tasks, change: .completion) {
            await apply(marking.changes(marking: subtask, as: .done), to: subtask)
        }
    }

    /// Changes decided on the day's view of `task` (`DayStateController.local`) go back into the note's own zone.
    @discardableResult
    func writeLocal(_ task: TaskItem, _ changes: [TaskEdit]) async -> Bool {
        await write(task, ZonedTimes.stored(changes, of: task, calendar: day.calendar))
    }

    /// A date picked on the day's view of a task (Soon): on the phone's clock, written in the note's own zone.
    func setLocalDue(_ due: TaskDue?, of name: String) async {
        await edit(name) { note in ZonedTimes.stored([.due(due)], of: note, calendar: self.day.calendar) }
    }

    /// The task filing made of the note that had this id, if it is still among the filed ones.
    func filed(from id: TaskID) -> TaskItem? {
        filedFrom[id].flatMap { tasks.filedTask($0.id) }
    }

    /// Done tasks are filed away by the store; the tasks that waited for them lose those met links first. Runs after every
    /// write that marks a task done and at every sync (a task done in Obsidian).
    func fileAwayDoneTasks() async {
        guard filesDoneTasks else { return }
        for task in DoneFiling.due(tasks.tasks) { await fileAway(task) }
    }

    private func fileAway(_ task: TaskItem) async {
        for dependent in DoneFiling.unlinking(task.name, from: tasks.tasks) {
            await edit(dependent.name) { _ in [.removePreviousTask(task.name)] }
        }
        do {
            try await backups.backup([task], reason: "done")
            let filed = try await store.fileAway(task)
            filedFrom[task.id] = filed
            tasks.remove(task)
            tasks.addFiled(filed)
            await derived.publish()
        } catch {
            SyncLog.logger.error("filing \(task.name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
