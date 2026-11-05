import Foundation
@preconcurrency import UserNotifications
import Testing
@testable import SuperPooperApp

/// Snooze on a delivered notification, through the app and the in-memory notification center: the shown one goes, the
/// same comes again later (half an hour, as the settings have it by default) and stays planned while its item is open and its day lasts.
@MainActor
struct SnoozeFlowTests {
    private let center = FakeNotificationCenter()
    private let context = PreviewSamples.context
    private let vitamins = "Витамины 💊"
    private var slot: String { NotificationPayload.prefix + NotificationPlanner.habitSlot(vitamins, LocalTime("09:00")) }

    private func at(_ time: String, daysLater: Int = 0) -> Date {
        context.date(context.today.adding(days: daysLater), LocalTime(time))
    }

    private struct App {
        let model: AppModel
        let clock: SettableClock
        let responses: NotificationResponseHandler

        func sync(at moment: Date) async {
            clock.now = moment
            await model.sync(announce: false)
            await model.waitForNotifications()
        }
    }

    private func app(events: [CalendarEvent] = []) throws -> App {
        let clock = SettableClock(at("08:30"))
        let scheduler = UserNotificationScheduler(calendar: FixedCalendar(current: PreviewSamples.calendar),
                                                  rules: TestConfig.rules.notifications,
                                                  icons: TestConfig.decode(IconSet.self, "icons.json"),
                                                  bodyText: { "body \($0.rawValue)" }, actionTitle: { $0 }, center: center)
        let model = try #require(PreviewModel.make(notifications: scheduler, calendars: FakeCalendars(events: events), clock: clock)).model
        let responses = NotificationResponseHandler(model: model, router: NotificationResponseRouter(links: TestConfig.rules.eventLinks)) { _ in }
        return App(model: model, clock: clock, responses: responses)
    }

    private func fireDate(_ request: UNNotificationRequest?) -> Date? {
        (request?.trigger as? UNCalendarNotificationTrigger).flatMap { PreviewSamples.calendar.date(from: $0.dateComponents) }
    }

    /// The pending requests that bring back the notification `shown` (same key and day, another identifier).
    private func snoozed(_ shown: UNNotificationRequest) -> [UNNotificationRequest] {
        let key = shown.content.userInfo[NotificationPayload.keyKey] as? String
        let day = shown.content.userInfo[NotificationPayload.dayKey] as? String
        return center.pending.filter {
            $0.identifier != shown.identifier && $0.content.userInfo[NotificationPayload.keyKey] as? String == key
                && $0.content.userInfo[NotificationPayload.dayKey] as? String == day
        }
    }

    /// The habit's 09:00 notification delivered and snoozed at 09:00.
    private func snoozeVitamins(_ app: App) async throws -> UNNotificationRequest {
        await app.sync(at: at("08:30"))
        app.clock.now = at("09:00")
        center.deliver(slot)
        let shown = try #require(center.delivered.first)
        await app.responses.handle(action: ActionID.snooze.rawValue, request: shown)
        return shown
    }

    @Test func aSnoozedHabitNotificationComesAgainInHalfAnHourAndSurvivesPlanning() async throws {
        let app = try app()
        let shown = try await snoozeVitamins(app)
        #expect(center.delivered.isEmpty, "the one shown goes")
        let again = try #require(snoozed(shown).first)
        #expect(fireDate(again) == at("09:30"))
        #expect(again.content.title == shown.content.title)
        #expect(again.content.body == shown.content.body)
        #expect(again.content.categoryIdentifier == shown.content.categoryIdentifier, "with the same buttons")
        #expect(fireDate(center.pending(slot)) == at("09:00", daysLater: 1), "tomorrow's notification keeps its place")
        #expect(app.model.task(named: vitamins)?.mark(on: context.today) == nil, "the habit itself does not change")

        await app.sync(at: at("09:20"))
        #expect(snoozed(shown).count == 1, "planning and syncing again keep it, once")
    }

    @Test func aSnoozedNotificationGoesWhenItsItemIsDone() async throws {
        let app = try app()
        let shown = try await snoozeVitamins(app)
        await app.model.perform(.done, on: vitamins)
        await app.model.waitForNotifications()
        #expect(snoozed(shown).isEmpty)
    }

    @Test func aSnoozedNotificationGoesWithItsDay() async throws {
        let app = try app()
        let shown = try await snoozeVitamins(app)
        await app.sync(at: at("05:00", daysLater: 1))
        #expect(snoozed(shown).isEmpty)
    }

    /// The snoozed notification shown and swiped away comes back like any other, once: the put-back copy is the only one.
    @Test func aSnoozedNotificationSwipedAwayComesBackOnce() async throws {
        let app = try app()
        let shown = try await snoozeVitamins(app)
        let again = try #require(snoozed(shown).first)
        app.clock.now = at("09:30")
        center.deliver(again.identifier)
        let swiped = try #require(center.dismiss(again.identifier))
        await app.responses.handle(action: UNNotificationDismissActionIdentifier, request: swiped)
        center.deliver(NotificationIdentifier.restored(again.identifier))
        await app.sync(at: at("09:35"))
        #expect(center.delivered.map(\.identifier) == [NotificationIdentifier.restored(again.identifier)])
        #expect(snoozed(shown).filter { $0.trigger is UNCalendarNotificationTrigger }.isEmpty, "nothing planned again on top")
    }

    /// An event alert comes again with its own text (the event's start), a reminder half an hour after the press; a task takes that moment as its time.
    @Test func eventsRemindersAndTasksSnoozeToo() async throws {
        let start = at("15:15")
        let standup = CalendarEvent(eventIdentifier: "standup", title: "Standup", start: start, end: at("16:15"), isAllDay: false,
                                    calendarID: "demo", calendarTitle: "Demo", colorHex: "#30B0C7", hasAlarm: true,
                                    alarmDates: [at("15:00")])
        let app = try app(events: [standup])
        await app.sync(at: at("14:30"))
        app.clock.now = at("15:00")
        let firing = center.pending.filter { fireDate($0) == at("15:00") }.map(\.identifier)
        #expect(firing.count == 2, "the event's alert and the reminder")
        firing.forEach(center.deliver)
        for shown in center.delivered {
            await app.responses.handle(action: ActionID.snooze.rawValue, request: shown)
            let again = try #require(snoozed(shown).first, "\(shown.content.title)")
            #expect(fireDate(again) == at("15:30"))
            #expect(again.content.body == shown.content.body, "\(shown.content.title) keeps its text")
        }
        app.clock.now = at("16:00")
        center.deliver(try #require(center.pending.first { $0.content.title == "Забрать посылку" && fireDate($0) == at("16:00") }).identifier)
        let task = try #require(center.delivered.first { $0.content.title == "Забрать посылку" })
        await app.responses.handle(action: ActionID.snooze.rawValue, request: task)
        #expect(center.pending.filter { $0.content.title == "Забрать посылку" }.map(fireDate) == [at("16:30")])
    }

    // MARK: - The timeline follows

    private func slotStart(_ app: App, _ name: String) -> Date? {
        app.model.plan(at: app.clock.now).timeline.first { slot in
            if case .task(let item) = slot.content { return item.id == name }
            return false
        }?.start
    }

    /// The habit's block moves on today's timeline to the time its notification comes again, for today only: the note
    /// keeps its time, tomorrow's notification keeps its place.
    @Test func aSnoozedHabitsBlockMovesOnTodaysTimelineWithItsNotification() async throws {
        let app = try app()
        let shown = try await snoozeVitamins(app)
        #expect(slotStart(app, vitamins) == at("09:30"))
        #expect(app.model.dayState.timeMoves == [TimeMove(task: vitamins, slot: LocalTime("09:00"), time: LocalTime("09:30"))])
        #expect(app.model.task(named: vitamins)?.habitTimes == [LocalTime("09:00")], "the note keeps its time")
        #expect(snoozed(shown).map(fireDate) == [at("09:30")], "one notification, where the block now stands")
        #expect(fireDate(center.pending(slot)) == at("09:00", daysLater: 1))
        let tomorrow = app.model.plan(at: app.clock.now, dayOffset: 1).timeline.first { slot in
            if case .task(let item) = slot.content { return item.id == vitamins }
            return false
        }?.start
        #expect(tomorrow == nil, "open today, it stands on today's line and not on tomorrow's timeline")
    }

    /// A timed task takes the snooze as its own time: its line, its block and its notification tell the same.
    @Test func aSnoozedTaskTakesThatMomentAsItsTime() async throws {
        let parcel = "Забрать посылку"
        let app = try app()
        await app.sync(at: at("15:30"))
        app.clock.now = at("16:00")
        center.deliver(try #require(center.pending.first { $0.content.title == parcel }).identifier)
        let shown = try #require(center.delivered.first)
        await app.responses.handle(action: ActionID.snooze.rawValue, request: shown)
        #expect(slotStart(app, parcel) == at("16:30"))
        #expect(app.model.task(named: parcel)?.due?.time == LocalTime("16:30"), "written to its line")
        #expect(app.model.dayState.timeMoves.isEmpty, "nothing kept apart from the line")
        #expect(center.delivered.isEmpty)
        #expect(center.pending.filter { $0.content.title == parcel }.map(fireDate) == [at("16:30")])
    }

    /// Dragged on the timeline later, the snoozed block takes its notification along: the one shown goes, one comes at the
    /// new time.
    @Test func aSnoozedBlockDraggedElsewhereTakesItsNotificationAlong() async throws {
        let app = try app()
        let shown = try await snoozeVitamins(app)
        await app.model.schedule(vitamins, slot: LocalTime("09:00"), at: at("12:00"))
        await app.model.waitForNotifications()
        #expect(slotStart(app, vitamins) == at("12:00"))
        #expect(snoozed(shown).map(fireDate) == [at("12:00")])
    }
}

