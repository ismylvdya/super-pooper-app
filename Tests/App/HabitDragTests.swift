import Foundation
@preconcurrency import UserNotifications
import Testing
@testable import SuperPooperApp

/// A habit's block dragged on today's timeline and to the pool (.3267), through the app and the in-memory notification
/// center: the note does not change, today's notification of that block follows it, tomorrow is as the note has it.
@MainActor
struct HabitDragTests {
    private let center = FakeNotificationCenter()
    private let context = PreviewSamples.context
    private let vitamins = "Витамины 💊"
    private let nine = LocalTime("09:00")
    private var slot: String { NotificationPayload.prefix + NotificationPlanner.habitSlot(vitamins, nine) }

    private func at(_ time: String, daysLater: Int = 0) -> Date {
        context.date(context.today.adding(days: daysLater), LocalTime(time))
    }

    private func app() throws -> (model: AppModel, clock: SettableClock) {
        let clock = SettableClock(at("08:30"))
        let scheduler = UserNotificationScheduler(calendar: FixedCalendar(current: PreviewSamples.calendar),
                                                  rules: TestConfig.rules.notifications,
                                                  icons: TestConfig.decode(IconSet.self, "icons.json"),
                                                  bodyText: { _ in "" }, actionTitle: { $0 }, center: center)
        return (try #require(PreviewModel.make(notifications: scheduler, clock: clock)).model, clock)
    }

    private func sync(_ model: AppModel) async {
        await model.sync(announce: false)
        await model.waitForNotifications()
    }

    private func fireDate(_ request: UNNotificationRequest?) -> Date? {
        (request?.trigger as? UNCalendarNotificationTrigger).flatMap { PreviewSamples.calendar.date(from: $0.dateComponents) }
    }

    /// The habit's pending notifications of today.
    private var todays: [UNNotificationRequest] {
        center.pending.filter {
            $0.content.title == vitamins && $0.content.userInfo[NotificationPayload.dayKey] as? String == context.today.isoString
        }
    }

    private func start(_ model: AppModel) -> String? {
        model.plan(at: model.clock.now).slot(vitamins).map { LocalTime($0.start, in: PreviewSamples.calendar).string }
    }

    @Test func aDraggedBlockMovesTodaysNotificationAndLeavesTheNoteAsItIs() async throws {
        let (model, clock) = try app()
        let note = try #require(model.task(named: vitamins))
        await sync(model)
        clock.now = at("09:05")
        center.deliver(slot)

        await model.schedule(vitamins, slot: nine, at: at("11:00"))
        await model.waitForNotifications()
        #expect(start(model) == "11:00")
        #expect(model.task(named: vitamins) == note, "nothing is written to the note")
        #expect(model.dayState.timeMoves == [TimeMove(task: vitamins, slot: nine, time: LocalTime("11:00"))])
        #expect(center.delivered.isEmpty, "the notification at the old time goes")
        #expect(todays.map(fireDate) == [at("11:00")], "today's comes at the new time")
        #expect(fireDate(center.pending(slot)) == at("09:00", daysLater: 1), "tomorrow's at the note's time")
    }

    @Test func droppedInThePoolItDoesNotRingTodayAndComesBackToTheTimelineFromThere() async throws {
        let (model, clock) = try app()
        await sync(model)
        clock.now = at("08:40")
        let order = model.plan(at: clock.now).pool.map(\.id) + [vitamins]
        await model.unschedule(vitamins, slot: nine, poolOrder: order)
        await model.waitForNotifications()
        #expect(model.plan(at: clock.now).pool.map(\.id).contains(vitamins))
        #expect(start(model) == nil)
        #expect(todays.isEmpty, "no notification today")
        #expect(fireDate(center.pending(slot)) == at("09:00", daysLater: 1))

        #expect(model.canDropOnTimeline(vitamins, slot: nil))
        await model.schedule(vitamins, at: at("12:00"))
        await model.waitForNotifications()
        #expect(start(model) == "12:00")
        #expect(!model.plan(at: clock.now).pool.map(\.id).contains(vitamins))
        #expect(todays.map(fireDate) == [at("12:00")])
    }

    @Test func theNextDayTheHabitIsAsItsNoteHasIt() async throws {
        let (model, clock) = try app()
        await sync(model)
        await model.schedule(vitamins, slot: nine, at: at("11:00"))
        clock.now = at("08:00", daysLater: 1)
        await sync(model)
        #expect(model.dayState.timeMoves.isEmpty)
        #expect(start(model) == "09:00")
    }

    /// A habit without reminder times has no block: it cannot be dropped on the timeline.
    @Test func aHabitWithoutTimesStaysInThePool() throws {
        let (model, _) = try app()
        #expect(!model.canDropOnTimeline("Выпить воды 💧", slot: nil))
        #expect(model.canDropInPool(vitamins, slot: nine))
    }
}
