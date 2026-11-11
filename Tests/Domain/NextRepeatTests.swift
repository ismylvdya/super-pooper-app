import Foundation
import Testing
@testable import SuperPooperApp

/// The next repeat under a habit's rule: its line's day, else the rule's first day from today on.
@Suite("Next repeat")
struct NextRepeatTests {
    private let wednesday = LocalDate(TestCalendar.wednesday)
    private var occurrence: TaskOccurrence { TaskOccurrence(days: TestCalendar.context().days) }

    @Test func theLineSaysTheDayAnOverdueOneToo() {
        let overdue = makeHabit("Laundry", rule: "DTSTART:20261019;FREQ=DAILY;INTERVAL=3", status: .habit) {
            $0.isOverdue = true
            $0.nextLine = TaskDue(day: LocalDate("2026-10-20"))
        }
        #expect(NextRepeat.day(of: overdue, today: wednesday, occurrence: occurrence) == LocalDate("2026-10-20"))
    }

    @Test func withoutALineTheRulesFirstDayFromToday() {
        let draft = makeHabit("Laundry", rule: "DTSTART:20261019;FREQ=DAILY;INTERVAL=3", status: .habit)
        #expect(NextRepeat.day(of: draft, today: wednesday, occurrence: occurrence) == LocalDate("2026-10-22"))
    }
}
