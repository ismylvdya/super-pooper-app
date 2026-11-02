import Foundation
@preconcurrency import UserNotifications
import Testing
@testable import SuperPooperApp

/// The words under a notification's title name what it is about: a repeatable task's says "Repeatable task", a habit's
/// "Habit". Wednesday 2026-10-21 in Belgrade, 08:00.
struct NotificationBodyTextTests {
    private let center = FakeNotificationCenter()
    private let context = TestCalendar.context(TestCalendar.wednesday, "08:00")
    private let vitamins = makeHabit("Vitamins", time: "09:00")
    private let bins = makeHabit("Take out the bins", time: "09:00") { $0.habit.repeatable = true }

    private func planned(_ task: TaskItem) throws -> PlannedNotification {
        try #require(NotificationPlanner(horizonDays: 1, limit: 64).plan(tasks: [task], reminders: [], skipped: [], context: context).first)
    }

    @Test func aRepeatableTasksNotificationIsAboutARepeatableTask() throws {
        #expect(try planned(bins).subject == .repeatable)
        #expect(try planned(vitamins).subject == .habit)
        #expect(try planned(bins).snoozed(until: context.now).subject == .repeatable, "Snooze brings back the same words")
    }

    @Test func everySubjectHasItsWords() {
        #expect(NotificationBodyText.text(for: .repeatable) == "Repeatable task")
        #expect(NotificationBodyText.text(for: .habit) == "Habit")
        for subject in PlannedNotification.Subject.allCases {
            #expect(NotificationBodyText.text(for: subject) != "notification.\(subject.rawValue).body", "\(subject)")
        }
    }

    @Test func theScheduledNotificationSaysIt() async throws {
        let scheduler = UserNotificationScheduler(calendar: FixedCalendar(current: TestCalendar.calendar), rules: TestConfig.rules.notifications,
                                                  icons: TestConfig.decode(IconSet.self, "icons.json"),
                                                  bodyText: NotificationBodyText.text(for:), actionTitle: { $0 }, center: center)
        let notes = [try planned(bins), try planned(vitamins)]
        await scheduler.sync(planned: notes, stillValid: notes, now: [])
        let bodies = Dictionary(uniqueKeysWithValues: center.pending.map { ($0.content.title, $0.content.body) })
        #expect(bodies == ["Take out the bins": "Repeatable task", "Vitamins": "Habit"])
    }
}
