import Foundation

/// What the user decides about today's pool: Skip today, Not today, the manual order, a drag in Soon across the
/// parts of the day, a task or a habit's block dragged onto the timeline or back to the pool, a task or a whole section
/// moved among a day's sections, tasks joined in a worm. The widgets and notifications follow.
@MainActor
final class DayCommands {
    let day: DayStateController
    let sections: DaySectionsController
    let tasks: TaskState
    let writer: NoteWriter
    let derived: DerivedStatePublisher
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

    /// Return to today (`SetAsideToday`): a habit skipped today is no longer skipped; a task put off today comes back
    /// into today's pool, as from a backlog page.
    func returnToToday(_ name: String) async {
        guard let task = tasks.task(named: name) else { return }
        if task.isHabit {
            day.unskip(name)
            await derived.publish()
        } else {
            await relocateTask(name, to: .pool(day: day.context().today, section: nil, order: []), fromScheduled: false, slot: nil)
        }
    }

    /// Not today for a task (`NotToday`).
    func notToday(_ name: String, on day: LocalDate?) async {
        guard isToday(day), let task = tasks.task(named: name), let local = localTask(named: name) else { return }
        await write(task, NotToday.changes(for: local, context: self.day.context()))
        await carrySubtasks(of: task, into: false)
    }

    /// The open subtasks of a task taken out of today's pool or brought into it go along (`TodayPool.following`).
    func carrySubtasks(of task: TaskItem, into inPool: Bool) async {
        for name in TodayPool.following(task, into: inPool, in: tasks.tasks) {
            await writer.edit(name) { _ in [.inTodayPool(inPool)] }
        }
    }

    /// The pool in a new order: its lines take that order in the store (D-180).
    func setPoolOrder(_ names: [String]) async {
        await writer.reorder(names)
    }

    /// Today's pool lines sorted by the pool's rules (`PoolSorter`).
    func resetOrder() async {
        await setPoolOrder(derived.sortedPool())
        appEvents.send(.orderReset)
    }

    /// Apply the same section and order changes for every view of a day's pool.
    func relocatePoolRows(_ groups: [(name: String, section: String)], order: [String]?, on date: LocalDate) async {
        for (name, section) in groups { placeInSection(name, section, on: date) }
        for (name, _) in groups { await writer.waitForEdits(of: name) }
        if let order { await setPoolOrder(order) }
        else if !groups.isEmpty { await derived.publish() }
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
        if isToday(shown) { await setPoolOrder(poolOrder) }
    }

    /// A block dragged from the timeline can land in the pool (`TaskScheduling.canSendToPool`).
    func canSendToPool(_ name: String, slot: LocalTime?) -> Bool {
        tasks.task(named: name).map { TaskScheduling.canSendToPool($0, slot: slot) } ?? false
    }

    // MARK: - Sections

    /// Dropped under a section's header in the pool of `date`: it stands in that section (a task's line says so, until the
    /// day's turn takes a section that does not last away; its routine stays as it is); the pool's order is today's only.
    func moveTask(_ name: String, toSection id: String, poolOrder: [String], on date: LocalDate) {
        moveTasks([name], toSection: id, poolOrder: poolOrder, on: date)
    }

    /// A worm dropped whole: every member goes into the section (nil: stays where it stands).
    func moveTasks(_ names: [String], toSection id: String?, poolOrder: [String], on date: LocalDate) {
        for name in names { placeInSection(name, id, on: date) }
        if isToday(date) { Task { await setPoolOrder(poolOrder) } }
        Task { await derived.publish() }
    }

    /// A note made from a "+" dropped in the pool of `day`: it takes the gap's place there and the section of the spot.
    /// A timeline's drop is already the note's date and time.
    func place(_ name: String, at placement: NewItemPlacement) async {
        if case .newSection(let title, let day) = placement {
            _ = newSection(titled: title, with: [name], after: nil, on: day)
            return
        }
        guard case .pool(_, let section, let day) = placement, let order = placement.poolOrder(named: name) else { return }
        placeInSection(name, section, on: day)
        if isToday(day) { await setPoolOrder(order) }
        await derived.publish()
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
        if isToday(date) {
            let tag = added.order.first { $0.id == id }.flatMap { PoolSectionTag.tag(of: $0, definitions: sections.definitions) }
            for name in added.membership.filter({ $0.value == id }).map(\.key) { writeSection(tag, of: name) }
        }
        Task { await derived.publish() }
        return id
    }

    /// A section's header edited in place: its title on `date` only; the next day starts from its own sections. The lines
    /// of an own section's tasks take its new tag.
    func renameSection(_ id: String, to title: String, on date: LocalDate) {
        let before = sections.snapshot(on: date)
        sections.update(on: date) { $0 = $0.renamingSection(id, to: title) }
        let definitions = sections.definitions
        if isToday(date), let old = before.order.first(where: { $0.id == id }),
           let new = sections.snapshot(on: date).order.first(where: { $0.id == id }),
           let oldTag = PoolSectionTag.tag(of: old, definitions: definitions) {
            let newTag = PoolSectionTag.tag(of: new, definitions: definitions)
            if newTag != oldTag {
                for task in tasks.tasks where task.poolSection == oldTag && !task.isHabit { writeSection(newTag, of: task.name) }
            }
        }
        Task { await derived.publish() }
    }

    /// Shown in the section at once; a task's line takes the section's tag on today (`PoolSectionTag`).
    func placeInSection(_ name: String, _ id: String?, on date: LocalDate) {
        guard let id else { return }
        sections.update(on: date) { sections in
            sections.membership = sections.membership.filter { !$0.key.isSameNoteName(as: name) }
            sections.membership[name] = id
        }
        guard isToday(date), let section = sections.snapshot(on: date).order.first(where: { $0.id == id }) else { return }
        writeSection(PoolSectionTag.tag(of: section, definitions: sections.definitions), of: name)
    }

    // MARK: - Subtasks

    /// A task let go over a list's right part: the subtask of the row above it (`SubtaskMove`).
    func nest(_ name: String, under parent: String, index: Int?) async {
        guard let task = tasks.task(named: name), let owner = tasks.task(named: parent),
              let edits = SubtaskMove.changes(moving: task, under: owner, index: index, in: tasks.tasks) else { return }
        await writer.write(task, edits)
    }

    /// The row above the dragged task's spot in `order` can take it as a subtask.
    func canNest(_ name: String, order: [String]) -> Bool {
        guard let at = order.firstIndex(of: name), at > 0, let task = tasks.task(named: name),
              let owner = tasks.task(named: order[at - 1]) else { return false }
        return SubtaskMove.changes(moving: task, under: owner, index: 0, in: tasks.tasks) != nil
    }

    /// A drop that cannot land: the banner says so.
    func refuseDrop(_ name: String, onto target: DropRefusal.Target) {
        Haptics.play(.dropRefused)
        appEvents.send(.dropRefused(DropRefusal(name: name, isHabit: tasks.task(named: name)?.isHabit ?? false, target: target)))
    }

    /// A task's new time written to its note: what a snooze moved of its old time today no longer applies.
    @discardableResult
    func write(_ task: TaskItem, _ changes: [TaskEdit]) async -> Bool {
        let today = day.todayTimes
        if today.moves.contains(where: { $0.task.isSameNoteName(as: task.name) }) { day.setTimeMoves(today.clearing(task)) }
        return await writer.writeLocal(task, changes)
    }

    private func isToday(_ date: LocalDate?) -> Bool {
        date == nil || date == day.context().today
    }
}
