import Foundation
import Testing
@testable import SuperPooper

/// Which local notifications should be pending (`<notifications>`), with the real horizon and limit
/// from `rules.json`. Wednesday 2026-10-21; the horizon is Wednesday … Tuesday 2026-10-27.
@Suite("Notification planning")
struct NotificationPlannerTests {
    private let planner = NotificationPlanner(horizonDays: TestConfig.rules.notifications.horizonDays,
                                              limit: TestConfig.rules.notifications.limit)
    private let vitamins = makeHabit("Vitamins 💊", time: "09:00")

    @Test func theConfigPlansAWeekAheadWithinTheIOSLimit() {
        #expect(TestConfig.rules.notifications.horizonDays == 7)
        #expect(TestConfig.rules.notifications.limit <= 64)
    }

    @Test func aTimedHabitGetsOneNotificationPerDayOfTheHorizon() {
        let planned = plan([vitamins], at: "08:00")
        #expect(planned.map(\.id) == days(21...27).map { "habit|Vitamins 💊|\($0)" })
        #expect(planned.map { clockTime($0.fireDate) } == Array(repeating: "09:00", count: 7))
        #expect(planned.map(\.day.isoString) == days(21...27))
        #expect(planned.allSatisfy { $0.kind == .habit && $0.taskName == "Vitamins 💊" && $0.title == "Vitamins 💊" })
    }

    @Test func aTimeThatHasPassedIsNeverPlanned() {
        #expect(plan([vitamins], at: "09:00").map(\.day.isoString) == days(22...27))
        #expect(plan([vitamins], at: "13:25").map(\.day.isoString) == days(22...27))
    }

    @Test func markedDaysAreNotPlanned() {
        let marked = vitamins.applying([.habitInstances(HabitInstances(
            complete: [LocalDate("2026-10-21"), LocalDate("2026-10-23")], partial: [LocalDate("2026-10-23")], twice: []))])
        #expect(plan([marked], at: "08:00").map(\.day.isoString) == ["2026-10-22"] + days(24...27))
    }

    @Test func skipTodayRemovesOnlyTodaysNotification() {
        #expect(plan([vitamins], at: "08:00", skipped: ["Vitamins 💊"]).map(\.day.isoString) == days(22...27))
    }

    @Test func onlyDaysOfTheRuleArePlanned() {
        let laundry = makeHabit("Laundry", rule: "DTSTART:20260905;FREQ=WEEKLY;BYDAY=SA", time: "10:00")
        #expect(plan([laundry], at: "08:00").map(\.day.isoString) == ["2026-10-24"])
    }

    @Test func untimedHabitsAndTasksAreNotPlanned() {
        let water = makeHabit("Water")
        let errand = makeTask("Errand") { $0.due = TaskDue("2026-10-21") }
        let undated = makeTask("Undated")
        #expect(plan([water, errand, undated], at: "08:00").isEmpty)
    }

    @Test func aTaskWithATimeInTheFutureIsPlannedOnce() throws {
        let parcel = makeTask("Pick up parcel") { $0.due = TaskDue("2026-10-21T16:00") }
        let friday = makeTask("Friday call", status: .halfYear) { $0.due = TaskDue("2026-10-23T10:00") }
        let planned = plan([friday, parcel], at: "13:25")
        #expect(planned.map(\.id) == ["task|Pick up parcel", "task|Friday call"])
        let first = try #require(planned.first)
        #expect(first.kind == .task && first.day == LocalDate("2026-10-21") && clockTime(first.fireDate) == "16:00")
    }

    @Test func pastAndCompletedTasksAreNotPlanned() {
        let past = makeTask("At noon") { $0.due = TaskDue("2026-10-21T12:00") }
        let done = makeTask("Done", status: .done) { $0.due = TaskDue("2026-10-21T18:00") }
        let archived = makeTask("Archived", status: .archived) { $0.due = TaskDue("2026-10-22T18:00") }
        #expect(plan([past, done, archived], at: "13:25").isEmpty)
    }

    @Test func remindersArePlannedUnlessCompletedOrPast() {
        let reminders = [makeReminder("Later", at: "15:00"), makeReminder("Done", at: "16:00", completed: true),
                         makeReminder("Earlier", at: "11:00")]
        let planned = planner.plan(tasks: [], reminders: reminders, skipped: [], context: TestCalendar.context())
        #expect(planned.map(\.title) == ["Later"])
        #expect(planned.first?.kind == .reminder && planned.first?.taskName == nil)
    }

    @Test func theLimitKeepsTheNearestOnesFirst() {
        let limited = NotificationPlanner(horizonDays: 7, limit: 3)
        let evening = makeHabit("Evening", time: "21:00")
        let parcel = makeTask("Parcel") { $0.due = TaskDue("2026-10-21T16:00") }
        let planned = limited.plan(tasks: [evening, vitamins, parcel], reminders: [makeReminder("Laundry out", at: "15:00")],
                                   skipped: [], context: TestCalendar.context(TestCalendar.wednesday, "13:25"))
        #expect(planned.map(\.title) == ["Laundry out", "Parcel", "Evening"])
        #expect(planned.map(\.fireDate) == planned.map(\.fireDate).sorted())
    }

    @Test func stillValidTodayKeepsTodaysEvenAfterTheirTime() {
        let parcel = makeTask("Parcel") { $0.due = TaskDue("2026-10-21T12:00") }
        let friday = makeTask("Friday") { $0.due = TaskDue("2026-10-23T12:00") }
        let water = makeHabit("Water at ten", time: "10:00")
        let context = TestCalendar.context(TestCalendar.wednesday, "13:25")
        let valid = planner.stillValidToday(tasks: [vitamins, parcel, friday, water], reminders: [], skipped: ["Water at ten"], context: context)
        #expect(Set(valid.map(\.id)) == ["habit|Vitamins 💊|2026-10-21", "task|Parcel"])

        let marked = vitamins.applying([.habitInstances(HabitInstances(complete: [LocalDate("2026-10-21")], partial: [], twice: []))])
        let doneParcel = parcel.applying([.status(.done), .completedDate(LocalDate("2026-10-21"))])
        #expect(planner.stillValidToday(tasks: [marked, doneParcel], reminders: [], skipped: [], context: context).isEmpty)
    }

    // MARK: - Helpers

    private func plan(_ tasks: [TaskNote], at time: String, skipped: Set<String> = []) -> [PlannedNotification] {
        planner.plan(tasks: tasks, reminders: [], skipped: skipped, context: TestCalendar.context(TestCalendar.wednesday, time))
    }

    private func days(_ range: ClosedRange<Int>) -> [String] { range.map { String(format: "2026-10-%02d", $0) } }
}
