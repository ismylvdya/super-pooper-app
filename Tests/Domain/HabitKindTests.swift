import Foundation
import Testing
@testable import SuperPooper

/// Habits as a kind of their own: `status: habit`, the rule alone decides the days, reminders decide the times.
@Suite("Habit kind")
struct HabitKindTests {
    private func habit(_ name: String, times: [String] = [], rule: String? = "DTSTART:20260901;FREQ=DAILY") -> TaskNote {
        makeTask(name, status: .habit) { task in
            task.reminderTimes = times.compactMap(LocalTime.init(string:))
            guard let rule else { return }
            task.recurrenceRaw = rule
            if case .success(let parsed) = RecurrenceRule.parse(rule) { task.recurrence = parsed }
        }
    }

    @Test func aHabitWithoutRemindersStaysInThePool() {
        #expect(DayScenario(tasks: [habit("Stretch")]).build().poolNames == ["Stretch"])
    }

    @Test func aHabitWithoutARuleIsDaily() {
        #expect(DayScenario(tasks: [habit("Stretch", rule: nil)]).build().poolNames == ["Stretch"])
    }

    @Test func aHabitIgnoresItsDueDateForTheDay() {
        var thursdays = habit("Thursdays", rule: "DTSTART:20261001;FREQ=WEEKLY;BYDAY=TH")
        thursdays.due = TaskDue("2026-10-21")
        #expect(DayScenario(tasks: [thursdays]).build().dayNames.isEmpty)
    }

    @Test func eachReminderIsItsOwnTimelineBlock() {
        let plan = DayScenario(tasks: [habit("Pills", times: ["09:00", "21:00"])]).build()
        #expect(plan.poolNames.isEmpty)
        let slots = plan.timeline.filter { $0.id.hasPrefix("task:Pills") }
        #expect(slots.map { clockTime($0.start) } == ["09:00", "21:00"])
        #expect(Set(slots.map(\.id)).count == 2)
    }

    @Test func eachReminderIsNotifiedOnItsOwn() {
        let planner = NotificationPlanner(horizonDays: 1, limit: 64)
        let context = TestCalendar.context(TestCalendar.wednesday, "08:00")
        let planned = planner.plan(tasks: [habit("Pills", times: ["09:00", "21:00"])], reminders: [], skipped: [], context: context)
        #expect(planned.map { clockTime($0.fireDate) } == ["09:00", "21:00"])
    }

    @Test func aLegacyDueTimeStillWorksAsTheOnlyReminder() {
        var old = habit("Old")
        old.due = TaskDue("2026-09-01T07:30")
        #expect(old.habitTimes == [LocalTime(hour: 7, minute: 30)!])
    }
}
