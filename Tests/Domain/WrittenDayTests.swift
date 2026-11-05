import Foundation
import Testing
@testable import SuperPooperApp

/// A habit without a start date counts from `date_created` as it was written, not as that moment falls in the phone's
/// zone: 22:30 on the 21st written in Belgrade is the 22nd's morning in Kiritimati (UTC+14), yet the habit starts on
/// the 21st there too.
struct WrittenDayTests {
    private let kiritimati = DayBoundary(calendar: TestCalendar.calendar(in: "Pacific/Kiritimati"), boundary: TestConfig.defaults.day.boundary)

    private var habit: TaskItem {
        makeHabit("Every other day", rule: "FREQ=DAILY;INTERVAL=2") {
            $0.dateCreated = TestCalendar.date(TestCalendar.wednesday, "22:30")
            $0.created = TaskDue("2026-10-21T22:30")
        }
    }

    @Test func theRecurrenceCountsFromTheWrittenDay() {
        let occurrence = TaskOccurrence(days: kiritimati)
        #expect(occurrence.occurs(habit, on: LocalDate("2026-10-21")))
        #expect(!occurrence.occurs(habit, on: LocalDate("2026-10-22")))
        #expect(occurrence.occurs(habit, on: LocalDate("2026-10-23")))
    }

    @Test func theHistoryStartsOnTheWrittenDay() {
        #expect(HabitHistory(task: habit, days: kiritimati).start(today: LocalDate("2026-10-25")) == LocalDate("2026-10-21"))
    }

}
