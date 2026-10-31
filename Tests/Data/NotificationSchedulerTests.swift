import Foundation
@preconcurrency import UserNotifications
import Testing
@testable import SuperPooperApp

/// What the scheduler leaves in the notification center: the plan pending, shown notifications while their item is
/// open, and a notification swiped away put back without touching tomorrow's. Wednesday 2026-10-21 in Belgrade.
struct NotificationSchedulerTests {
    private let center = FakeNotificationCenter()
    private let planner = NotificationPlanner(horizonDays: TestConfig.rules.notifications.horizonDays,
                                              limit: TestConfig.rules.notifications.limit)
    private let water = makeHabit("Вода", status: .habit) { $0.reminderTimes = [LocalTime("09:00")] }
    private let slot = NotificationPayload.prefix + NotificationPlanner.habitSlot("Вода", LocalTime("09:00"))

    private var scheduler: UserNotificationScheduler {
        UserNotificationScheduler(calendar: FixedCalendar(current: TestCalendar.calendar),
                                  icons: TestConfig.decode(IconSet.self, "icons.json"),
                                  bodyText: { _ in "" }, actionTitle: { $0 }, center: center)
    }

    /// The app's sync at `time` on `day` (Wednesday).
    private func sync(_ tasks: [TaskItem], at time: String, on day: String = TestCalendar.wednesday) async {
        let context = TestCalendar.context(day, time)
        await scheduler.sync(planned: planner.plan(tasks: tasks, reminders: [], skipped: [], context: context),
                             stillValid: planner.stillValidToday(tasks: tasks, reminders: [], skipped: [], context: context),
                             now: [])
    }

    private func fireDate(_ identifier: String) -> Date? {
        (center.pending(identifier)?.trigger as? UNCalendarNotificationTrigger)
            .flatMap { TestCalendar.calendar.date(from: $0.dateComponents) }
    }

    /// Today's 09:00 rang and tomorrow's 09:00 waits under the slot identifier.
    private func todayRang() async {
        await sync([water], at: "08:00")
        center.deliver(slot)
        await sync([water], at: "09:30")
    }

    @Test func thePlanIsWhatStaysPending() async {
        await sync([water], at: "08:00")
        #expect(fireDate(slot) == TestCalendar.date(TestCalendar.wednesday, "09:00"))
        #expect(center.pending.count == TestConfig.rules.notifications.horizonDays)
        await sync([], at: "08:00")
        #expect(center.pending.isEmpty)
    }

    @Test func aShownNotificationStaysWhileItsDayIsOpen() async {
        await todayRang()
        #expect(center.delivered.map(\.identifier) == [slot])
        #expect(fireDate(slot) == TestCalendar.date("2026-10-22", "09:00"))
        await sync([water.applying([.mark(.done, on: LocalDate(TestCalendar.wednesday))])], at: "09:40")
        #expect(center.delivered.isEmpty)
    }

    /// The reported bug: today's notification swiped away came back under the slot identifier and took the place of
    /// tomorrow's pending one, so tomorrow stayed silent.
    @Test func aSwipedNotificationComesBackWithoutReplacingTomorrows() async throws {
        await todayRang()
        let swiped = try #require(center.dismiss(slot))
        await scheduler.restore(swiped)
        #expect(fireDate(slot) == TestCalendar.date("2026-10-22", "09:00"))
        let restored = try #require(center.pending(NotificationIdentifier.restored(slot)))
        #expect(restored.content.sound == nil)
        #expect(restored.trigger is UNTimeIntervalNotificationTrigger)
    }

    /// A sync in the moment before the restored notification shows does not take it away.
    @Test func aSyncRightAfterARestoreKeepsTheRestoredNotification() async throws {
        await todayRang()
        await scheduler.restore(try #require(center.dismiss(slot)))
        await sync([water], at: "09:31")
        #expect(center.pending(NotificationIdentifier.restored(slot)) != nil)
        center.deliver(NotificationIdentifier.restored(slot))
        await sync([water], at: "09:32")
        #expect(center.delivered.map(\.identifier) == [NotificationIdentifier.restored(slot)])
        #expect(fireDate(slot) == TestCalendar.date("2026-10-22", "09:00"))
    }

    @Test func aRestoredNotificationGoesWhenItsItemIsDone() async throws {
        await todayRang()
        await scheduler.restore(try #require(center.dismiss(slot)))
        center.deliver(NotificationIdentifier.restored(slot))
        await sync([water.applying([.mark(.done, on: LocalDate(TestCalendar.wednesday))])], at: "09:40")
        #expect(center.delivered.isEmpty)
    }

    /// As a shown notification is replaced by the next one of its slot, one put back gives way to it.
    @Test func aRestoredNotificationGivesWayToTheNextOfItsSlot() async throws {
        await todayRang()
        await scheduler.restore(try #require(center.dismiss(slot)))
        center.deliver(NotificationIdentifier.restored(slot))
        // Thursday 09:00: the slot's next notification rings while Wednesday's put back one is still shown.
        center.deliver(slot)
        await sync([water], at: "09:40", on: "2026-10-22")
        #expect(center.delivered.map(\.identifier) == [slot])
    }

    /// An item moved to a later time gets a request at the new time; an alert moved into the past comes at once.
    @Test func aMovedItemIsRescheduledAndALateOneSentAtOnce() async {
        let call = makeTask("Позвонить") { $0.due = TaskDue("2026-10-21T18:00") }
        await sync([call], at: "08:00")
        let moved = makeTask("Позвонить") { $0.due = TaskDue("2026-10-21T19:00") }
        await sync([moved], at: "08:00")
        #expect(center.pending.compactMap(\.trigger).count == 1)
        #expect(center.pending.first.flatMap { fireDate($0.identifier) } == TestCalendar.date(TestCalendar.wednesday, "19:00"))

        let context = TestCalendar.context(TestCalendar.wednesday, "20:00")
        let late = planner.all(tasks: [moved], reminders: [], skipped: [], context: context)
        await scheduler.sync(planned: [], stillValid: late, now: late)
        #expect(center.delivered.map(\.identifier).allSatisfy { $0.hasSuffix("|late") })
        #expect(center.delivered.count == 1)
    }
}
