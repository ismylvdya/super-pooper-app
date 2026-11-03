import Foundation
@preconcurrency import UserNotifications
import Testing
@testable import SuperPooperApp

/// What a swipe, a tap or a button on a notification asks for, and that the app does it.
@MainActor
struct NotificationResponseTests {
    private let links = TestConfig.rules.eventLinks
    private var router: NotificationResponseRouter { NotificationResponseRouter(links: links) }
    private let start = TestCalendar.date(TestCalendar.wednesday, "10:00")

    // MARK: - Router

    /// A swipe puts the notification back; a tap does too and opens an event in Calendar, a reminder in Reminders.
    @Test func swipesAndTapsPutTheNotificationBack() {
        let event: [AnyHashable: Any] = ["kind": "event", "event": "EV-1", "eventStart": start.timeIntervalSince1970]
        #expect(router.route(action: UNNotificationDismissActionIdentifier, info: event) == .putBack(opening: nil))
        #expect(router.route(action: UNNotificationDefaultActionIdentifier, info: event) == .putBack(opening: links.calendarURL(at: start)))
        #expect(router.route(action: UNNotificationDefaultActionIdentifier, info: ["kind": "habit", "task": "Water"])
            == .putBack(opening: DeepLink.habit("Water")))
    }

    @Test func theButtonsOfRemindersAndEvents() {
        #expect(router.route(action: "done", info: ["kind": "reminder", "reminder": "REM-1"]) == .completeReminder(id: "REM-1"))
        let event: [AnyHashable: Any] = ["kind": "event", "event": "EV-1", "eventStart": start.timeIntervalSince1970]
        #expect(router.route(action: "deleteEvent", info: event) == .deleteEvent(identifier: "EV-1", start: start))
        // Without its start an occurrence cannot be told from the others: nothing is deleted.
        #expect(router.route(action: "deleteEvent", info: ["kind": "event", "event": "EV-1"]) == .ignore)
    }

    /// Snooze on any notification names it by its key and day; one delivered before notifications carried a key is left.
    @Test func snoozeCarriesTheNotificationsKeyAndDay() {
        #expect(router.route(action: "snooze", info: ["kind": "event", "key": "event|EV-1|0", "day": "2026-10-21"])
            == .snooze(key: "event|EV-1|0", day: LocalDate("2026-10-21")))
        #expect(router.route(action: "snooze", info: ["kind": "habit", "task": "Water", "day": "2026-10-21"]) == .ignore)
    }

    /// A task's or habit's button acts on the day of the notification (none written: today).
    @Test func theButtonsOfTasksAndHabitsCarryTheirDay() {
        #expect(router.route(action: "done", info: ["kind": "habit", "task": "Water", "day": "2026-10-20"])
            == .perform(.done, taskName: "Water", day: LocalDate("2026-10-20")))
        #expect(router.route(action: "skipToday", info: ["kind": "habit", "task": "Water"]) == .perform(.skipToday, taskName: "Water", day: nil))
        #expect(router.route(action: "done", info: ["kind": "task"]) == .ignore)
        #expect(router.route(action: "unknown", info: ["kind": "task", "task": "Report"]) == .ignore)
    }

    // MARK: - Handler

    private func request(_ info: [AnyHashable: Any], id: String = "sp|habit|Вода|09:00") -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.userInfo = info
        return UNNotificationRequest(identifier: id, content: content, trigger: nil)
    }

    @Test func aTapPutsTheNotificationBackAndOpensItsEvent() async throws {
        let recorder = RecordingNotifications()
        let model = try #require(PreviewModel.make(notifications: recorder)).model
        var opened: [URL] = []
        let handler = NotificationResponseHandler(model: model, router: router) { opened.append($0) }
        let today = model.context().today.isoString
        let info: [AnyHashable: Any] = ["kind": "event", "day": today, "event": "EV-1", "eventStart": start.timeIntervalSince1970]
        await handler.handle(action: UNNotificationDefaultActionIdentifier, request: request(info))
        #expect(await recorder.log == ["restore sp|habit|Вода|09:00"])
        #expect(opened == [try #require(links.calendarURL(at: start))])
    }

    /// Dismiss alert on an event alert takes only the shown notification away: nothing is put back or opened.
    @Test func dismissAlertRemovesOnlyTheShownNotification() async throws {
        let recorder = RecordingNotifications()
        let model = try #require(PreviewModel.make(notifications: recorder)).model
        var opened: [URL] = []
        let handler = NotificationResponseHandler(model: model, router: router) { opened.append($0) }
        let info: [AnyHashable: Any] = ["kind": "event", "day": model.context().today.isoString, "event": "EV-1",
                                        "eventStart": start.timeIntervalSince1970]
        #expect(router.route(action: "dismissAlert", info: info) == .dismiss)
        await handler.handle(action: "dismissAlert", request: request(info, id: "sp|event|EV-1"))
        #expect(await recorder.log == ["remove sp|event|EV-1"])
        #expect(opened.isEmpty)
    }

    /// Two presses in a row run one after another: the second Done of a habit with two reminders is Twice.
    @Test func habitButtonsRunInOrder() async throws {
        let water = "Выпить воды 💧"
        let tasks = PreviewSamples.tasks.map { task -> TaskItem in
            guard task.name == water else { return task }
            var habit = task
            habit.reminderTimes = [LocalTime("09:00"), LocalTime("21:00")]
            return habit
        }
        let model = try #require(PreviewModel.make(tasks: tasks)).model
        let handler = NotificationResponseHandler(model: model, router: router) { _ in }
        let today = model.context().today
        let press = request(["kind": "habit", "task": water, "day": today.isoString])
        async let first: Void = handler.handle(action: "done", request: press)
        async let second: Void = handler.handle(action: "done", request: press)
        _ = await (first, second)
        #expect(model.task(named: water)?.mark(on: today) == .twice)
    }
}
