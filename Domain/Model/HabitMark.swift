import Foundation

/// The single mark a recurring task can have for a day.
enum HabitMark: String, Codable, CaseIterable, Sendable {
    case done
    case partial
    case twice
}

/// The three TaskNotes instance lists of a recurring task. Every marked day is in `complete`;
/// `partial` and `twice` refine it.
struct HabitInstances: Hashable, Sendable {
    var complete: [LocalDate]
    var partial: [LocalDate]
    var twice: [LocalDate]

    init(complete: [LocalDate], partial: [LocalDate], twice: [LocalDate]) {
        self.complete = complete
        self.partial = partial
        self.twice = twice
    }

    init(task: TaskNote) {
        self.init(complete: task.completeInstances, partial: task.partialInstances, twice: task.twiceInstances)
    }

    func mark(on day: LocalDate) -> HabitMark? {
        guard complete.contains(day) else { return nil }
        if twice.contains(day) { return .twice }
        if partial.contains(day) { return .partial }
        return .done
    }

    /// Sets exactly one mark for `day` (or clears it with `nil`).
    func setting(_ mark: HabitMark?, on day: LocalDate) -> HabitInstances {
        var result = self
        result.complete = HabitInstances.update(complete, day, include: mark != nil)
        result.partial = HabitInstances.update(partial, day, include: mark == .partial)
        result.twice = HabitInstances.update(twice, day, include: mark == .twice)
        return result
    }

    private static func update(_ list: [LocalDate], _ day: LocalDate, include: Bool) -> [LocalDate] {
        if include { return list.contains(day) ? list : list + [day] }
        return list.filter { $0 != day }
    }
}
