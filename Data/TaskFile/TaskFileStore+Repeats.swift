import Foundation

/// A habit's one open line: in Today on a day it comes up and is not closed, otherwise in Soon with the nearest day its
/// rule has. The settings stay in its JSON file; the line says what stands for the nearest day (`docs/BACKEND.md`).
extension TaskFileStore {
    /// The habit's rule as a schedule; nil for what has no line: archived, a subtask, or a rule the app cannot read.
    func schedule(of file: HabitFile, snapshot: Snapshot) -> (item: TaskItem, schedule: TaskSchedule)? {
        guard !file.isArchived, file.parent == nil else { return nil }
        let item = habit(of: file, snapshot: snapshot)
        guard item.recurrence != nil else { return nil }
        let days = DayBoundary(calendar: .current, boundary: .midnight)
        return (item, TaskOccurrence(days: days).schedule(of: item))
    }

    /// The day has turned over a habit's open line. On a day its rule has again the line just starts anew (the mirror writes
    /// it); otherwise what was left undone stands in today's pool, with no time and marked overdue, until it is done or
    /// its rule's next day comes.
    func carryMissedHabits(_ snapshot: inout Snapshot, to day: LocalDate) {
        for file in snapshot.habits.values {
            guard let line = snapshot.document.openLine(of: file.id), let date = logicalDay(of: line), date < day else { continue }
            guard let (item, schedule) = schedule(of: file, snapshot: snapshot) else { continue }
            guard var carried = snapshot.document.remove(where: { $0.id == file.id && $0.completed == nil })?.entry else { continue }
            guard item.habit.showInToday, !isClosed(item, on: date), !schedule.occurs(on: day) else { continue }
            carried.date = day
            carried.time = nil
            carried.zone = nil
            carried.alarm = nil
            carried.isOverdue = true
            snapshot.document.insert(carried, into: .now)
        }
    }

    /// The line a habit has for `date`, at `time`.
    func habitLine(_ file: HabitFile, item: TaskItem, date: LocalDate?, time: LocalTime?, isOverdue: Bool = false) -> TaskEntry {
        var entry = TaskEntry(name: file.name)
        entry.id = file.id
        entry.date = date
        entry.time = time
        entry.zone = time == nil ? nil : file.timeZone
        entry.estimate = file.timeEstimate
        entry.isHigh = file.isHighPriority
        entry.feel = file.feel
        entry.routine = file.options.timeOfDay?.rawValue
        entry.repeats = item.recurrence.map(RepeatTag.text)
        entry.isOverdue = isOverdue
        if let time, let alarm = file.alarms?.first(where: { $0.time == time }) {
            entry.alarm = alarm.sound ?? format.alarmDefaultSound
        }
        return entry
    }

    /// Whether the habit's day is over: closed by its marks.
    func isClosed(_ item: TaskItem, on day: LocalDate) -> Bool {
        HabitMarking.isDayClosed(item.mark(on: day), twiceADay: item.isTwiceADay)
    }

    /// The habits with no line in today's look wait in Next actions, each on the nearest day after today its rule has: today is
    /// closed, skipped or not theirs. One taken out of today (`skipped`) with no day of its own tomorrow stands in tomorrow's pool,
    /// with no time and marked overdue, as what the day leaves unfinished does (`Tomorrow`).
    func waitingHabitLines(except placed: Set<String>, skipped: [String], snapshot: Snapshot, today day: LocalDate) -> [TaskEntry] {
        let tomorrow = day.adding(days: 1)
        return snapshot.habits.values.sorted { $0.name < $1.name }.compactMap { file in
            guard !placed.contains(file.id), let (item, schedule) = schedule(of: file, snapshot: snapshot) else { return nil }
            let next = schedule.recurrence?.firstDay(onOrAfter: tomorrow)
            if next != tomorrow, skipped.containsNoteName(file.name), !isClosed(item, on: day) {
                return habitLine(file, item: item, date: tomorrow, time: nil, isOverdue: true)
            }
            return next.map { habitLine(file, item: item, date: $0, time: file.reminderTimes.first) }
        }
    }
}

extension TaskFileStore: TaskOrdering {
    /// The lines of `ids` take the places they have between them in the order given; every other line stays where it is.
    func reorder(_ ids: [TaskID]) async throws {
        try await location.withRoot { root in
            var snapshot = try await read(root: root)
            let wanted = ids.map(\.value)
            let members = Set(wanted)
            for section in snapshot.document.sections.indices {
                for group in snapshot.document.sections[section].groups.indices {
                    let entries = snapshot.document.sections[section].groups[group].entries
                    let places = entries.indices.filter { entries[$0].id.map(members.contains) ?? false }
                    guard places.count > 1 else { continue }
                    let here = wanted.compactMap { id in entries.first { $0.id == id } }
                    for (place, entry) in zip(places, here) { snapshot.document.sections[section].groups[group].entries[place] = entry }
                }
            }
            try write(snapshot.document, root: root)
        }
    }
}
