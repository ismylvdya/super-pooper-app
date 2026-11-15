import Foundation

/// What the store's file says about today comes into the app: the habits kept out of today and their times, the
/// sections the tasks' lines name; and a task's section goes into its line.
extension DayCommands {
    /// Today's look as it was changed elsewhere (by hand in the file, on another device): the habits kept out of today
    /// become the app's.
    func applyLook(_ look: DayLook) {
        for name in look.skipped { day.skip(name) }
    }

    /// The sections the tasks' lines name (`PoolSectionTag`): a section of today no section has yet is made, and a task
    /// stands where its line says — the app keeps a section of its own only for a habit, which has no tag.
    func takeSectionTags() {
        let today = day.context().today
        let definitions = sections.definitions
        let tags = Array(Set(tasks.tasks.filter { !$0.isHabit && $0.isInTodayPool }.compactMap(\.poolSection))).sorted()
        let habits = Set(tasks.tasks.filter(\.isHabit).map(\.name.noteName))
        sections.update(on: today) { current in
            current = current.addingTagged(tags, definitions: definitions, makeID: { UUID().uuidString })
            current.membership = current.membership.filter { habits.contains($0.key.noteName) }
        }
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

    /// A task's line names the section it stands in; a habit's stays as it is.
    func writeSection(_ tag: String?, of name: String) {
        guard let task = tasks.task(named: name), !task.isHabit, task.poolSection != tag else { return }
        writer.enqueueEdit(name) { _ in [.poolSection(tag)] }
    }
}
