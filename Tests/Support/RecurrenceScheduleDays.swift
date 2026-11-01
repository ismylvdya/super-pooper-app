import Foundation
@testable import SuperPooperApp

/// The tests read a rule's days the way the app does: day by day through `occurs(on:)`.
extension RecurrenceSchedule {
    /// The days in `start...end` the rule occurs on.
    func occurrences(from start: LocalDate, through end: LocalDate) -> [LocalDate] {
        guard start <= end else { return [] }
        return (0...start.days(until: end)).map { start.adding(days: $0) }.filter { occurs(on: $0) }
    }

    /// The first day on or after `day` the rule occurs on, within a hundred years.
    func nextOccurrence(onOrAfter day: LocalDate) -> LocalDate? {
        (0...36_600).lazy.map { day.adding(days: $0) }.first { occurs(on: $0) }
    }
}
