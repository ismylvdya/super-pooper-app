import Foundation

/// What the user decides about today's pool: Skip today, Not today, the manual order, a drag in Soon across the
/// parts of the day, a task or a habit's block dragged onto the timeline or back to the pool, a task or a whole section
/// moved among a day's sections, tasks joined in a worm. The widgets and notifications follow.
@MainActor
final class DayCommands {
    private let day: DayStateController
    private let sections: DaySectionsController
    private let tasks: TaskState
    private let writer: NoteWriter
    private let derived: DerivedStatePublisher
    private let appEvents: AppEventSink

    init(day: DayStateController, sections: DaySectionsController, tasks: TaskState, writer: NoteWriter, derived: DerivedStatePublisher,
         appEvents: AppEventSink) {
        self.day = day
        self.sections = sections
        self.tasks = tasks
        self.writer = writer
        self.derived = derived
        self.appEvents = appEvents
    }

    /// The day's view of a task (times on the phone's clock).
    func localTask(named name: String) -> TaskItem? {
        tasks.task(named: name).map(day.local)
    }

    /// Only on today's page (`day` nil or today).
    func skip(_ name: String, on day: LocalDate?) async {
        guard isToday(day) else { return }
        self.day.skip(name)
        await derived.publish()
    }

    /// Not today for a task (`NotToday`).
    func notToday(_ name: String, on day: LocalDate?) async {
        guard isToday(day), let task = tasks.task(named: name) else { return }
        await write(task, NotToday.changes())
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
    /// that day, or a block of that day's own for a habit without reminder times.
    func schedule(_ name: String, slot: LocalTime?, at moment: Date) async {
        guard let task = tasks.task(named: name), let local = localTask(named: name) else { return }
        guard task.isHabit else {
            await write(task, TaskScheduling.changes(scheduling: task, at: moment, calendar: day.calendar))
            return
        }
        let time = LocalTime(moment, in: day.calendar)
        let shown = day.context().logicalDay(of: moment)
        let times = day.times(on: shown)
        day.setTimeMoves(slot.map { times.moving(local, slot: $0, to: time) } ?? times.placing(local, at: time), on: shown)
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

    /// A block dragged from the timeline can land in the pool (`TaskScheduling.canSendToPool`).
    func canSendToPool(_ name: String, slot: LocalTime?) -> Bool {
        tasks.task(named: name).map { TaskScheduling.canSendToPool($0, slot: slot) } ?? false
    }

    // MARK: - Sections

    /// Dropped under a section's header in the pool of `date`: it stands in that section that day only (its routine and
    /// note stay as they are); the pool's order is today's only.
    func moveTask(_ name: String, toSection id: String, poolOrder: [String], on date: LocalDate) {
        moveTasks([name], toSection: id, poolOrder: poolOrder, on: date)
    }

    /// A worm dropped whole: every member goes into the section (nil: stays where it stands).
    func moveTasks(_ names: [String], toSection id: String?, poolOrder: [String], on date: LocalDate) {
        for name in names { placeInSection(name, id, on: date) }
        if isToday(date) { day.setManualOrder(poolOrder) }
        Task { await derived.publish() }
    }

    /// A note made from a "+" dropped in the pool of `day`: it takes the gap's place there and the section of the spot.
    /// A timeline's drop is already the note's date and time.
    func place(_ name: String, at placement: NewItemPlacement) {
        if case .newSection(let title, let day) = placement {
            _ = newSection(titled: title, with: [name], after: nil, on: day)
            return
        }
        guard case .pool(_, let section, let day) = placement, let order = placement.poolOrder(named: name) else { return }
        if section != nil {
            moveTasks([name], toSection: section, poolOrder: order, on: day)
        } else if isToday(day) {
            setManualOrder(order)
        }
    }

    /// A whole section dragged by its header: the day's sections in the new order (`order`: their ids).
    func moveSection(_ id: String, order: [String], on date: LocalDate) {
        sections.update(on: date) { sections in
            let byID = Dictionary(sections.order.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let moved = order.compactMap { byID[$0] }
            sections.order = moved + sections.order.filter { !order.contains($0.id) }
        }
        Task { await derived.publish() }
    }

    /// Select → Worm: the tasks share one plate on `date` (a worm one of them was in takes the others along). It is the
    /// app's only: nothing is written to the notes.
    func worm(_ names: [String], on date: LocalDate) {
        sections.update(on: date) { $0 = $0.worming(names, id: UUID().uuidString) }
        Task { await derived.publish() }
    }

    func unworm(_ names: [String], on date: LocalDate) {
        sections.update(on: date) { $0 = $0.unworming(names) }
        Task { await derived.publish() }
    }

    /// Select → New section: an own section of `date` titled `title`, after the section `after`, takes the tasks. Its id,
    /// or nil for a blank title.
    func newSection(titled title: String, with names: [String], after: String?, on date: LocalDate) -> String? {
        let id = UUID().uuidString
        guard let added = sections.snapshot(on: date).addingSection(id: id, titled: title, with: names, after: after) else { return nil }
        sections.update(on: date) { $0 = added }
        Task { await derived.publish() }
        return id
    }

    /// A section's header edited in place: its title on `date` only; the next day starts from its own sections.
    func renameSection(_ id: String, to title: String, on date: LocalDate) {
        sections.update(on: date) { $0 = $0.renamingSection(id, to: title) }
        Task { await derived.publish() }
    }

    /// Today's look as it was changed elsewhere (by hand in the file, on another device): its sections, each line's
    /// section and order, and what is kept out of today become the app's.
    func applyLook(_ look: DayLook) {
        let today = day.context().today
        let definitions = sections.definitions
        sections.update(on: today) { current in
            current = current.applying(look, title: { section in
                section.title ?? definitions.first { $0.id == section.id }.map { L10n.string($0.title) } ?? section.id
            }, makeID: { UUID().uuidString })
        }
        for name in look.skipped { day.skip(name) }
        day.setManualOrder(look.poolOrder)
    }

    /// A habit's line got another time in the file: its first block stands there today, its settings stay.
    /// What the habits' lines say about today: a habit's first block stands at its line's time, or in the pool for a line with
    /// no time. The file wins over what this device remembers; a second block of a day has no line of its own.
    func takeTimes(of look: DayLook) {
        for (name, time) in look.times ?? [:] {
            guard let habit = tasks.task(named: name), habit.isHabit else { continue }
            if TodayTimes(day.dayState.timeMoves).blocks(of: habit).first?.time != time { moveHabit(named: name, to: time) }
        }
        for name in look.untimed {
            guard let habit = tasks.task(named: name), habit.isHabit else { continue }
            let today = TodayTimes(day.dayState.timeMoves)
            if let block = today.blocks(of: habit).first { day.setTimeMoves(today.pooling(habit, slot: block.written)) }
        }
    }

    private func moveHabit(named name: String, to time: LocalTime) {
        guard let habit = tasks.task(named: name), habit.isHabit else { return }
        let today = TodayTimes(day.dayState.timeMoves)
        let blocks = today.blocks(of: habit)
        let moves = blocks.first.map { today.moving(habit, slot: $0.written, to: time) } ?? today.placing(habit, at: time)
        day.setTimeMoves(moves)
    }

    private func placeInSection(_ name: String, _ id: String?, on date: LocalDate) {
        guard let id else { return }
        sections.update(on: date) { sections in
            sections.membership = sections.membership.filter { !$0.key.isSameNoteName(as: name) }
            sections.membership[name] = id
        }
    }

    // MARK: - Backlog pages

    /// Dropped on the backlog page of `level` while `shown` is shown (`BacklogMoves.onto`); `fromShownDay`: from that day's
    /// pool or timeline.
    func moveToBacklog(_ name: String, level: TaskStatus, shown: LocalDate, fromShownDay: Bool) async {
        guard let local = localTask(named: name) else { return }
        let outcome = BacklogMoves.onto(level, task: local, fromShownDay: fromShownDay, shown: shown, context: day.context())
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

    /// A drop that cannot land: the banner says so.
    func refuseDrop(_ name: String, onto target: DropRefusal.Target) {
        Haptics.play(.dropRefused)
        appEvents.send(.dropRefused(DropRefusal(name: name, isHabit: tasks.task(named: name)?.isHabit ?? false, target: target)))
    }

    /// A task can come out of a backlog page into a day: a task, not a habit (which has no planning level to change).
    func canBringFromBacklog(_ name: String) -> Bool {
        tasks.task(named: name).map { !$0.isHabit } ?? false
    }

    private func apply(_ outcome: BacklogMoves.Outcome, to name: String) async {
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
