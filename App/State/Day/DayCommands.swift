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

    /// Dropped on the timeline of any day: a task's moment is read on the phone's clock and written in the note's own
    /// zone; a habit's block stands there on that day only and its note stays as it is (`TodayTimes`). `slot`: the habit
    /// block's time as its note has it, when it comes from the timeline; from the pool the habit's first time sent there
    /// that day.
    func schedule(_ name: String, slot: LocalTime?, at moment: Date) async {
        guard let task = tasks.task(named: name), let local = localTask(named: name) else { return }
        guard task.isHabit else {
            await write(task, TaskScheduling.changes(scheduling: task, at: moment, calendar: day.calendar))
            return
        }
        let time = LocalTime(moment, in: day.calendar)
        let shown = day.context().logicalDay(of: moment)
        let times = day.times(on: shown)
        guard let moves = slot.map({ times.moving(local, slot: $0, to: time) }) ?? times.placing(local, at: time) else { return }
        day.setTimeMoves(moves, on: shown)
        await derived.publish()
    }

    /// Back to the pool at the spot it was dropped on, on the logical day it was shown on (`shown`, nil: today): a task
    /// loses its time, a habit's block (`slot`) leaves that day's timeline and does not ring then. The pool's order is
    /// today's only.
    func unschedule(_ name: String, slot: LocalTime?, poolOrder: [String], on shown: LocalDate? = nil) async {
        guard let task = tasks.task(named: name), let local = localTask(named: name) else { return }
        let shown = shown ?? day.context().today
        if task.isHabit {
            guard let slot else { return }
            day.setTimeMoves(day.times(on: shown).pooling(local, slot: slot), on: shown)
            await derived.publish()
        } else {
            await write(task, TaskScheduling.changes(unscheduling: local, context: day.context()))
        }
        if isToday(shown) { setManualOrder(poolOrder) }
    }

    /// A dragged item can land on the timeline of `shown` (nil: today) (`TaskScheduling.canPlace`).
    func canPlaceOnTimeline(_ name: String, slot: LocalTime?, on shown: LocalDate? = nil) -> Bool {
        let times = day.times(on: shown ?? day.context().today)
        return localTask(named: name).map { TaskScheduling.canPlace($0, slot: slot, today: times) } ?? false
    }

    /// A block dragged from the timeline can land in the pool (`TaskScheduling.canSendToPool`).
    func canSendToPool(_ name: String, slot: LocalTime?) -> Bool {
        tasks.task(named: name).map { TaskScheduling.canSendToPool($0, slot: slot) } ?? false
    }

    // MARK: - Backlog pages

    /// Dropped on the backlog page of `level` while `shown` is shown (`BacklogMoves.onto`); `fromShownDay`: from that day's
    /// pool or timeline.
    func moveToBacklog(_ name: String, level: TaskStatus, shown: LocalDate, fromShownDay: Bool) async {
        guard let local = localTask(named: name) else { return }
        let outcome = BacklogMoves.onto(level, task: local, fromShownDay: fromShownDay, shown: shown, context: day.context())
        if outcome.isNotToday { return await notToday(name, on: shown) }
        await apply(outcome, to: name)
    }

    /// From a backlog page into the pool of `day` (`BacklogMoves.intoPool`), at the dropped spot when it is today.
    func bringFromBacklog(_ name: String, to day: LocalDate, poolOrder: [String]?) async {
        guard let local = localTask(named: name) else { return }
        await apply(BacklogMoves.intoPool(local, day: day, context: self.day.context()), to: name)
        if let poolOrder, isToday(day) { setManualOrder(poolOrder) }
    }

    /// From a backlog page onto the timeline of any day, at the dropped moment.
    func scheduleFromBacklog(_ name: String, at moment: Date) async {
        guard let local = localTask(named: name) else { return }
        await apply(BacklogMoves.ontoTimeline(local, at: moment, context: day.context()), to: name)
    }

    /// A task can come out of a backlog page into a day: a task, not a habit (which has no planning level to change).
    func canBringFromBacklog(_ name: String) -> Bool {
        tasks.task(named: name).map { !$0.isHabit } ?? false
    }

    private func apply(_ outcome: BacklogMoves.Outcome, to name: String) async {
        if outcome.postpones { day.postpone(name) }
        if outcome.unpostpones { day.unpostpone(name) }
        if !outcome.edits.isEmpty, let task = tasks.task(named: name) { await write(task, outcome.edits) }
        await derived.publish()
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
