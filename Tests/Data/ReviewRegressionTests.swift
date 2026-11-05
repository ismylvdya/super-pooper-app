import Foundation
import Testing
@testable import SuperPooperApp

/// Regressions from the code review: concurrent edits, odd files and name collisions.
@Suite("Review regressions")
struct ReviewRegressionTests {
}

/// Times between midnight and the day boundary belong to the end of the logical day.
@Suite("Day boundary")
struct DayBoundaryTests {
    @Test func aHabitAfterMidnightIsPlacedAtTheEndOfToday() throws {
        let night = makeHabit("Night pills", time: "00:30")
        let plan = DayScenario(tasks: [night]).build(at: TestCalendar.context("2026-10-21", "22:00"))
        let slot = try #require(plan.slot("Night pills"))
        #expect(slot.start == TestCalendar.date("2026-10-22", "00:30"))
    }

    @Test func aTaskDueAfterMidnightBelongsToThePreviousLogicalDay() throws {
        let late = makeTask("Late call") { $0.due = TaskDue("2026-10-22T01:00") }
        let plan = DayScenario(tasks: [late]).build(at: TestCalendar.context("2026-10-21", "22:00"))
        #expect(plan.slot("Late call")?.start == TestCalendar.date("2026-10-22", "01:00"))
        #expect(TestCalendar.context().logicalDay(of: TaskDue("2026-10-22T01:00")) == LocalDate("2026-10-21"))
    }

    @Test func aNightHabitNotificationBelongsToItsLogicalDay() throws {
        let night = makeHabit("Night pills", time: "00:30")
        let planned = NotificationPlanner(horizonDays: 1, limit: 10)
            .plan(tasks: [night], reminders: [], skipped: [], context: TestCalendar.context("2026-10-21", "22:00"))
        let first = try #require(planned.first)
        #expect(first.day == LocalDate("2026-10-21"))
        #expect(first.fireDate == TestCalendar.date("2026-10-22", "00:30"))
    }
}
