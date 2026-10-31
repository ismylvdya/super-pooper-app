import Foundation
import Testing
@testable import SuperPooperApp

/// A habit without a start date counts from `date_created` as it was written, not as that moment falls in the phone's
/// zone: 22:30 on the 21st written in Belgrade is the 22nd's morning in Kiritimati (UTC+14), yet the habit starts on
/// the 21st there too.
struct WrittenDayTests {
    private let kiritimati = DayBoundary(calendar: TestCalendar.calendar(in: "Pacific/Kiritimati"), boundary: TestConfig.defaults.day.boundary)

    private var habit: TaskNote {
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

    /// The written clock, whatever the offset after it and whatever zone the phone reads it in.
    @Test func theReaderKeepsTheWrittenDateAndTime() throws {
        let text = "---\ntags:\n  - t\nstatus: habit\ndate_created: 2026-10-21T22:30:44.123+02:00\n---\n"
        for zone in ["Pacific/Kiritimati", "America/New_York"] {
            let reader = TaskNoteReader(mapping: TestConfig.mapping, taskTag: "t", calendar: TestCalendar.calendar(in: zone))
            let task = reader.task(from: try FrontmatterDocument(text: text), name: "Habit", relativePath: "Habit.md")
            #expect(task.created == TaskDue("2026-10-21T22:30"))
            #expect(task.dateCreated == ISO8601.parse("2026-10-21T20:30:44.123Z"))
        }
    }
}
