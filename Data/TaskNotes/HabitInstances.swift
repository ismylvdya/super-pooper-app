import Foundation

/// The three TaskNotes instance lists of a recurring task and the marks they mean: every marked day is in `complete`;
/// `partial` and `twice` refine it (twice wins over partial). A day only in a refining list has no mark.
struct HabitInstances: Hashable, Sendable {
    var complete: [LocalDate]
    var partial: [LocalDate]
    var twice: [LocalDate]

    var marks: [LocalDate: HabitMark] {
        Dictionary(complete.map { day in
            (day, twice.contains(day) ? .twice : partial.contains(day) ? .partial : .done)
        }, uniquingKeysWith: { first, _ in first })
    }
}
