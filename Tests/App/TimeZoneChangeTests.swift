import Foundation
import Testing
@testable import SuperPooperApp

/// The phone changes its time zone while the app stays open (the reported bug: Jakarta in the evening, then Serbia,
/// a task set to 6 November showed up on 7 November until a relaunch).
@MainActor
struct TimeZoneChangeTests {
    /// 21:30 UTC on 6 November: 04:30 on the 7th in Jakarta (past the 04:00 boundary), 22:30 on the 6th in Belgrade.
    private let now = ISO8601.parse("2026-11-06T21:30:00Z") ?? .distantPast

    private func makeModel(calendar: TravellingCalendar, notifications: NotificationScheduling = SilentNotifications()) throws -> AppModel {
        let tasks = [
            makeTask("Pay rent") { $0.due = TaskDue("2026-11-06") },
            makeTask("Late call") { $0.due = TaskDue("2026-11-06T23:00") },
        ]
        return try #require(PreviewModel.make(notifications: notifications, calendar: calendar, clock: FixedClock(now: now),
                                              tasks: tasks)).model
    }

    @Test func theDayFollowsANewZoneWithoutARelaunch() async throws {
        let calendar = TravellingCalendar("Asia/Jakarta")
        let model = try makeModel(calendar: calendar)
        #expect(model.context().today == LocalDate("2026-11-07"))

        calendar.fly(to: "Europe/Belgrade")
        await model.timeDidChange()

        #expect(model.calendar.timeZone.identifier == "Europe/Belgrade")
        #expect(model.context().today == LocalDate("2026-11-06"))
        let rent = try #require(model.task(named: "Pay rent"))
        #expect(QuickDue.selection(of: rent.due, context: model.context()) == .today)
    }

    /// Wall-clock times ring at the same clock time in the new zone: 23:00 is 23:00 in Belgrade, still ahead.
    @Test func notificationsArePlannedAgainInTheNewZone() async throws {
        let calendar = TravellingCalendar("Asia/Jakarta")
        let recorder = RecordingNotifications()
        let model = try makeModel(calendar: calendar, notifications: recorder)
        await model.publishDerivedState()
        await model.waitForNotifications()
        #expect(await !recorder.lastPlanned.contains { $0.taskName == "Late call" })

        calendar.fly(to: "Europe/Belgrade")
        await model.timeDidChange()
        await model.waitForNotifications()

        let call = try #require(await recorder.lastPlanned.first { $0.taskName == "Late call" })
        #expect(call.fireDate == ISO8601.parse("2026-11-06T22:00:00Z"))
    }
}
