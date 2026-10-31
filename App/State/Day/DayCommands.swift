import Foundation

/// What the user decides about today's pool: Skip today, Not today, the manual order, a drag in This week across the
/// parts of the day, a task dragged onto the timeline or back to the pool. The widgets and notifications follow.
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

    var postponedTasks: [TaskItem] { day.postponedNames.compactMap(tasks.task(named:)) }

    /// Only on today's page (`day` nil or today).
    func skip(_ name: String, on day: LocalDate?) async {
        guard isToday(day) else { return }
        self.day.skip(name)
        await derived.publish()
    }

    /// Not today (`NotToday`): a task with a time moves to the same time of the next logical day, any other waits in
    /// This week until tomorrow.
    func notToday(_ name: String, on day: LocalDate?) async {
        guard isToday(day), let task = tasks.task(named: name), let local = localTask(named: name) else { return }
        let changes = NotToday.changes(for: local, context: self.day.context())
        if changes.isEmpty { postpone(name) } else { await writer.writeLocal(task, changes) }
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

    /// A drag in This week across the Morning / Day / Evening groups: the new order, and a new part of the day for the
    /// tasks that changed group.
    func applyReviewMove(_ move: ReviewGroups.Move) {
        setManualOrder(move.order)
        for (name, group) in move.regrouped {
            writer.enqueueEdit(name) { _ in [.timeOfDay(group.timeOfDay)] }
        }
    }

    /// Dropped on the timeline: the moment is read on the phone's clock and written in the note's own zone.
    func schedule(_ name: String, at moment: Date) async {
        guard let task = tasks.task(named: name) else { return }
        await writer.writeLocal(task, TaskScheduling.changes(scheduling: task, at: moment, calendar: day.calendar))
    }

    /// Back to the pool at the spot it was dropped on, on the logical day it was shown on.
    func unschedule(_ name: String, poolOrder: [String]) async {
        guard let task = tasks.task(named: name), let local = localTask(named: name) else { return }
        await writer.writeLocal(task, TaskScheduling.changes(unscheduling: local, context: day.context()))
        setManualOrder(poolOrder)
    }

    private func isToday(_ date: LocalDate?) -> Bool {
        date == nil || date == day.context().today
    }
}
