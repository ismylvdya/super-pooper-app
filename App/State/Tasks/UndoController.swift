import Foundation

/// Undo (.27143): an action from a menu or a swipe that can be taken back happens at once, and the banner offers Undo
/// for a few seconds instead of asking first. A step remembers, as they were, the notes the action may change — the note,
/// the subtasks that go along with it, the tasks waiting for any of them (filing a done task unlinks them) — and what was
/// decided about today. Taking it back puts all of that back: notes out of the trash or the done folder, their fields,
/// today's decisions. Only the latest step can be taken back.
@MainActor
final class UndoController {
    struct Step: Equatable {
        let id = UUID()
        let action: ActionID
        let name: String
        /// The notes as they were before the action.
        let notes: [TaskItem]
        /// The subtasks that go along with the note.
        let along: [String]
        let day: DayState
        /// The days' pool sections (a delete takes the notes out of them).
        let sections: [DaySections]
        /// Where the deleted notes lie in the trash.
        var trashed: [TrashedNote] = []
        /// A task of the done folder deleted from the Done list: taken back, it lies there again as it was.
        var filed: TaskItem?
    }

    private let tasks: TaskState
    private let writer: NoteWriter
    private let store: TaskStore
    private let trash: TaskTrash?
    private let day: DayStateController
    private let sections: DaySectionsController
    private let derived: DerivedStatePublisher
    private let appEvents: AppEventSink
    private(set) var last: Step?

    init(tasks: TaskState, writer: NoteWriter, store: TaskStore, trash: TaskTrash?, day: DayStateController,
         sections: DaySectionsController, derived: DerivedStatePublisher, appEvents: AppEventSink) {
        self.tasks = tasks
        self.writer = writer
        self.store = store
        self.trash = trash
        self.day = day
        self.sections = sections
        self.derived = derived
        self.appEvents = appEvents
    }

    /// The action can be taken back here (`actions.json` → `undo`): a delete only where the store has a trash.
    func canUndo(_ action: ActionDefinition) -> Bool {
        switch action.undo {
        case .edits: true
        case .trash: trash != nil
        case nil: false
        }
    }

    /// What the action on the note may change, as it is before the action runs.
    func begin(_ action: ActionID, on name: String) -> Step? {
        guard let note = tasks.task(named: name) else { return nil }
        let along = action.subtaskChange.map { SubtaskCascade.subtasks(of: note, in: tasks.tasks, change: $0) } ?? []
        let going = [note] + along
        let waiting = going.flatMap { NameReferences.waiting(for: $0.name, in: tasks.tasks) }
        var notes: [TaskItem] = []
        for task in going + waiting where !notes.contains(where: { $0.id == task.id }) { notes.append(task) }
        return Step(action: action, name: note.name, notes: notes, along: along.map(\.name), day: day.dayState,
                    sections: sections.storedSnapshots())
    }

    /// What a delete of a task of the done folder changes: only that file, which goes to the trash.
    func begin(_ action: ActionID, onFiled task: TaskItem) -> Step {
        Step(action: action, name: task.name, notes: [], along: [], day: day.dayState, sections: sections.storedSnapshots(), filed: task)
    }

    /// The action has run: when it changed anything, the banner offers to take it back.
    func offer(_ step: Step, trashed: [TrashedNote]) {
        var step = step
        step.trashed = trashed
        guard trashed.count > 0 || day.dayState != step.day || step.notes.contains(where: { tasks.task(named: $0.name) != $0 })
        else { return }
        last = step
        appEvents.send(.undoable(UndoOffer(id: step.id, action: step.action, name: step.name, along: step.along)))
    }

    /// Puts back what the step's action changed; a step that is no longer the latest is left alone.
    func undo(_ id: UUID) async {
        guard let step = last, step.id == id else { return }
        last = nil
        do {
            try await bringBack(step)
        } catch {
            appEvents.send(.failure(AppFailure(error)))
        }
        for before in step.notes {
            guard let now = tasks.task(named: before.name) else { continue }
            await writer.write(now, TaskRestoring.edits(restoring: before, from: now), cascades: false)
        }
        day.restore(step.day)
        sections.restore(step.sections)
        await derived.publish()
    }

    /// The deleted notes out of the trash (a filed one back into the done folder), the tasks filed as done back among the
    /// active ones.
    private func bringBack(_ step: Step) async throws {
        if let trash, !step.trashed.isEmpty {
            for note in step.trashed { _ = try await trash.restore(note) }
            await tasks.reload(from: store)
            // The trash puts a note back among the tasks; a done one goes on into the done folder, where it was.
            if step.filed != nil { await writer.fileAwayDoneTasks() }
        }
        for before in step.notes where tasks.task(named: before.name) == nil {
            guard let filed = writer.filed(from: before.id) else { continue }
            let back = try await store.unfile(filed)
            tasks.removeFiled(filed)
            tasks.written(back)
        }
    }
}

/// The banner's offer to take an action back.
struct UndoOffer: Equatable, Sendable {
    let id: UUID
    let action: ActionID
    let name: String
    /// The subtasks that went along with it.
    var along: [String] = []
}
