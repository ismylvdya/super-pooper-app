import Foundation

/// What the user decides about today's pool: Skip today, Not today, the manual order, a drag in Soon across the
/// parts of the day, a task or a habit's block dragged onto the timeline or back to the pool. The widgets and
/// notifications follow.
@MainActor
final class DayCommands {
    private let day: DayStateController
    private let tasks: TaskState
    private let writer: NoteWriter
    private let derived: DerivedStatePublisher
    private let appEvents: AppEventSink

    init(day: DayStateController, tasks: TaskState, writer: NoteWriter, derived: DerivedStatePublisher, appEvents: AppEventSink) {
        self.day = day
        self.tasks = tasks
        self.writer = writer
        self.derived = derived
        self.appEvents = appEvents
    }

    /// The day's view of a task (times on the phone's clock).
    func localTask(named name: String) -> TaskItem? {
        tasks.task(named: name).map(day.local)
    }

    var postponedTasks: [TaskItem] { day.postponedNames.compactMap(tasks.task(named:)).filter { $0.status != .done } }

    /// Only on today's page (`day` nil or today).
    func skip(_ name: String, on day: LocalDate?) async {
        guard isToday(day) else { return }
        self.day.skip(name)
        await derived.publish()
    }

    /// Not today (`NotToday`): a task with a time moves to the same time of the next logical day, any other waits in
    /// Soon until tomorrow.
    func notToday(_ name: String, on day: LocalDate?) async {
        guard isToday(day), let task = tasks.task(named: name), let local = localTask(named: name) else { return }
        let changes = NotToday.changes(for: local, context: self.day.context())
        if changes.isEmpty { postpone(name) } else { await write(task, changes) }
    }

    /// The morning review takes a task out of today; it stays this week and is back tomorrow.
    func postpone(_ name: String) {
        day.postpone(name)
        Task { await derived.publish() }
    }

    func unpostpone(_ name: String) {
        day.unpostpone(name)
        Task { await derived.publish() }
    }

    func setManualOrder(_ names: [String]) {
        day.setManualOrder(names)
        Task { await derived.publish() }
    }

    func resetOrder() {
        day.setManualOrder(nil)
        appEvents.send(.orderReset)
        Task { await derived.publish() }
    }

    /// A drag in Soon across the Morning / Day / Evening groups: the new order, and a new part of the day for the
    /// tasks that changed group.
    func applyReviewMove(_ move: ReviewGroups.Move) {
        setManualOrder(move.order)
        for (name, group) in move.regrouped {
            writer.enqueueEdit(name) { _ in [.timeOfDay(group.timeOfDay)] }
        }
    }

    /// Dropped on the timeline: a task's moment is read on the phone's clock and written in the note's own zone; a
    /// habit's block stands there today only and its note stays as it is (`TodayTimes`). `slot`: the habit block's
    /// time as its note has it, when it comes from the timeline; from the pool the habit's first time sent there today.
    func schedule(_ name: String, slot: LocalTime?, at moment: Date) async {
        guard let task = tasks.task(named: name), let local = localTask(named: name) else { return }
        guard task.isHabit else {
            await write(task, TaskScheduling.changes(scheduling: task, at: moment, calendar: day.calendar))
            return
        }
        let time = LocalTime(moment, in: day.calendar)
        let today = day.todayTimes
        guard let moves = slot.map({ today.moving(local, slot: $0, to: time) }) ?? today.placing(local, at: time) else { return }
        day.setTimeMoves(moves)
        await derived.publish()
    }

    /// Back to the pool at the spot it was dropped on, on the logical day it was shown on: a task loses its time, a
    /// habit's block (`slot`) leaves today's timeline and does not ring today.
    func unschedule(_ name: String, slot: LocalTime?, poolOrder: [String]) async {
        guard let task = tasks.task(named: name), let local = localTask(named: name) else { return }
        if task.isHabit {
            guard let slot else { return }
            day.setTimeMoves(day.todayTimes.pooling(local, slot: slot))
            await derived.publish()
        } else {
            await write(task, TaskScheduling.changes(unscheduling: local, context: day.context()))
        }
        setManualOrder(poolOrder)
    }

    /// A dragged item can land on today's timeline (`TaskScheduling.canPlace`).
    func canPlaceOnTimeline(_ name: String, slot: LocalTime?) -> Bool {
        localTask(named: name).map { TaskScheduling.canPlace($0, slot: slot, today: day.todayTimes) } ?? false
    }

    /// A block dragged from the timeline can land in the pool (`TaskScheduling.canSendToPool`).
    func canSendToPool(_ name: String, slot: LocalTime?) -> Bool {
        tasks.task(named: name).map { TaskScheduling.canSendToPool($0, slot: slot) } ?? false
    }

    /// A task's new time written to its note: what a snooze moved of its old time today no longer applies.
    private func write(_ task: TaskItem, _ changes: [TaskEdit]) async {
        let today = day.todayTimes
        if today.moves.contains(where: { $0.task.isSameNoteName(as: task.name) }) { day.setTimeMoves(today.clearing(task)) }
        await writer.writeLocal(task, changes)
    }

    private func isToday(_ date: LocalDate?) -> Bool {
        date == nil || date == day.context().today
    }
}
