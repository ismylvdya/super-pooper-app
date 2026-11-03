import Foundation
import Testing
@testable import SuperPooperApp

/// Times are wall-clock unless an item keeps them in a zone of its own; then they move to the phone's zone.
struct ZonedTimesTests {
    private var berlin: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    @Test func withoutAZoneTimesStayAsTheyAre() {
        let task = makeTask("Call") { $0.due = TaskDue("2026-10-21T09:00"); $0.reminderTimes = [LocalTime("09:00")] }
        #expect(ZonedTimes.local(task, calendar: berlin, today: LocalDate("2026-10-21")) == task)
    }

    @Test func aZonedTimeMovesToThePhonesZone() {
        let task = makeTask("Call") {
            $0.timeZone = "Europe/Moscow"
            $0.due = TaskDue("2026-10-21T09:00")
            $0.reminderTimes = [LocalTime("01:30")]
        }
        let local = ZonedTimes.local(task, calendar: berlin, today: LocalDate("2026-10-21"))
        // On 21 October Moscow is UTC+3 and Berlin, still on summer time, UTC+2.
        #expect(local.due == TaskDue("2026-10-21T08:00"))
        #expect(local.reminderTimes == [LocalTime("00:30")])
    }

    /// A habit's time kept in `due` carries the day its rule starts (here in September, when Sydney is on standard time):
    /// the time moves as it falls today, on summer time, and the day stays as written.
    @Test func aZonedHabitsDueTimeMovesAsItFallsToday() {
        var istanbul = Calendar(identifier: .gregorian)
        istanbul.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let habit = makeHabit("Call mum", status: .habit) { $0.timeZone = "Australia/Sydney"; $0.due = TaskDue("2026-09-01T09:00") }
        let local = ZonedTimes.local(habit, calendar: istanbul, today: LocalDate("2026-11-04"))
        #expect(local.due == TaskDue("2026-09-01T01:00"))
        #expect(local.habitTimes == [LocalTime("01:00")])
    }

    /// What the day decides on the phone's clock goes back into the item's zone, so the note keeps its own times.
    @Test func aStoredTimeUndoesTheMoveToThePhonesZone() {
        let task = makeTask("Call") { $0.timeZone = "Europe/Moscow"; $0.due = TaskDue("2026-10-21T09:00") }
        let local = ZonedTimes.local(task, calendar: berlin, today: LocalDate("2026-10-21"))
        #expect(ZonedTimes.stored(local.due, of: task, calendar: berlin) == TaskDue("2026-10-21T09:00"))
        #expect(ZonedTimes.stored(TaskDue("2026-10-22"), of: task, calendar: berlin) == TaskDue("2026-10-22"))
        let plain = makeTask("Plain")
        #expect(ZonedTimes.stored(TaskDue("2026-10-22T08:00"), of: plain, calendar: berlin) == TaskDue("2026-10-22T08:00"))
    }

    /// A Jakarta task dropped at 10:00 on a Belgrade phone is written as 15:00 Jakarta time (and read back as 10:00),
    /// not as 10:00 Jakarta time.
    @Test func aDropOnTheTimelineIsWrittenInTheItemsZone() {
        let task = makeTask("Standup") { $0.timeZone = "Asia/Jakarta" }
        let changes = TaskScheduling.changes(scheduling: task, at: TestCalendar.date(TestCalendar.wednesday, "10:00"), calendar: TestCalendar.calendar)
        #expect(ZonedTimes.stored(changes, of: task, calendar: TestCalendar.calendar) == [.due(TaskDue("2026-10-21T15:00"))])
    }

    /// 08:00 in Jakarta on the 22nd is 03:00 in Belgrade, still the 21st's logical day: Today, not Tomorrow; Tomorrow
    /// moves it a day on the phone's clock and writes it back in Jakarta time.
    @Test func theQuickChipsJudgeAZonedTaskOnThePhonesDay() {
        let task = makeTask("Standup") { $0.timeZone = "Asia/Jakarta"; $0.due = TaskDue("2026-10-22T08:00") }
        let context = TestCalendar.context()
        #expect(QuickDue.selection(of: task, context: context) == .today)
        #expect(QuickDue.toggling(.tomorrow, task: task, context: context) == TaskDue("2026-10-23T08:00"))
    }
}
