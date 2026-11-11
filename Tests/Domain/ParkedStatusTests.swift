import Foundation
import Testing
@testable import SuperPooperApp

/// A task in Soon or Someday is put aside: it stays out of the pool, the timeline and the morning review, even dated
/// today, until moved back.
@Suite("Put aside in Soon or Someday")
struct ParkedStatusTests {
    private let morning = TestCalendar.context(TestCalendar.wednesday, "08:00")
    private let today = TaskDue(day: LocalDate(TestCalendar.wednesday))

    @Test func aTaskInSomedayOrSoonIsNotInTheDayEvenDatedToday() {
        let someday = makeTask("Paint", status: .someday) { $0.due = today }
        let soon = makeTask("Dentist", status: .halfYear)
        #expect(DayScenario(tasks: [someday, soon]).build(at: morning).dayNames.isEmpty)
    }
}
