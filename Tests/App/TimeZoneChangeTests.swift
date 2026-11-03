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
        await model.parts.derived.publish()
        await model.waitForNotifications()
        #expect(await !recorder.lastPlanned.contains { $0.taskName == "Late call" })

        calendar.fly(to: "Europe/Belgrade")
        await model.timeDidChange()
        await model.waitForNotifications()

        let call = try #require(await recorder.lastPlanned.first { $0.taskName == "Late call" })
        #expect(call.fireDate == ISO8601.parse("2026-11-06T22:00:00Z"))
    }

    // MARK: A flight from Sydney to Istanbul

    /// 20:00 UTC on 4 November: 07:00 on the 5th in Sydney (summer time, UTC+11), 23:00 on the 4th in Istanbul (UTC+3).
    private let beforeTheFlight = ISO8601.parse("2026-11-04T20:00:00Z") ?? .distantPast

    private func travelling(_ tasks: [TaskItem], from zone: String, at now: Date,
                            notifications: RecordingNotifications) throws -> (AppModel, TravellingCalendar) {
        let calendar = TravellingCalendar(zone)
        let model = try #require(PreviewModel.make(notifications: notifications, calendar: calendar, clock: FixedClock(now: now),
                                                   tasks: tasks)).model
        return (model, calendar)
    }

    private func planned(_ name: String, by recorder: RecordingNotifications) async throws -> PlannedNotification {
        try #require(await recorder.lastPlanned.first { $0.taskName == name })
    }

    /// Without a zone 09:00 is the clock's 09:00: in Sydney it rings at 09:00 there, after the flight at 09:00 in Istanbul.
    @Test func aHabitWithoutAZoneRingsAtNineWhereverThePhoneIs() async throws {
        let recorder = RecordingNotifications()
        let water = makeHabit("Water", status: .habit) { $0.reminderTimes = [LocalTime("09:00")] }
        let (model, calendar) = try travelling([water], from: "Australia/Sydney", at: beforeTheFlight, notifications: recorder)
        await model.parts.derived.publish()
        await model.waitForNotifications()
        #expect(try await planned("Water", by: recorder).fireDate == ISO8601.parse("2026-11-04T22:00:00Z"))

        calendar.fly(to: "Europe/Istanbul")
        await model.timeDidChange()
        await model.waitForNotifications()

        let ring = try await planned("Water", by: recorder)
        #expect(!ring.isAbsolute)
        #expect(ring.fireDate == ISO8601.parse("2026-11-05T06:00:00Z"))
    }

    /// 09:00 Sydney time on the 5th is 01:00 in Istanbul, the night of the 4th's logical day: the timeline puts it there
    /// and it rings at that moment; after a further flight to Belgrade the moment stays, at 23:00 on the phone's clock.
    @Test func aTaskWithAZoneRingsAtItsMomentAndStandsThereOnTheTimeline() async throws {
        let recorder = RecordingNotifications()
        let call = makeTask("Board call") { $0.due = TaskDue("2026-11-05T09:00"); $0.timeZone = "Australia/Sydney" }
        let evening = ISO8601.parse("2026-11-04T15:00:00Z") ?? .distantPast
        let (model, calendar) = try travelling([call], from: "Europe/Istanbul", at: evening, notifications: recorder)
        let moment = ISO8601.parse("2026-11-04T22:00:00Z")
        await model.parts.derived.publish()
        await model.waitForNotifications()
        let slot = try #require(model.plan(at: evening).slot("Board call"))
        #expect(slot.start == moment)
        #expect(LocalTime(slot.start, in: model.calendar).string == "01:00")
        let ring = try await planned("Board call", by: recorder)
        #expect(ring.isAbsolute)
        #expect(ring.fireDate == moment)

        calendar.fly(to: "Europe/Belgrade")
        await model.timeDidChange()
        await model.waitForNotifications()

        let moved = try #require(model.plan(at: evening).slot("Board call"))
        #expect(moved.start == moment)
        #expect(LocalTime(moved.start, in: model.calendar).string == "23:00")
        #expect(try await planned("Board call", by: recorder).fireDate == moment)
    }

    /// A zone change plans the habits again too: one in Sydney time keeps its moment across the flight, whatever the
    /// season of the day its rule starts on (its time is kept in `due`, as a note from Obsidian may have it).
    @Test func aZoneChangePlansTheNotificationsAgain() async throws {
        let recorder = RecordingNotifications()
        let mum = makeHabit("Call mum", status: .habit) { $0.due = TaskDue("2026-09-01T09:00"); $0.timeZone = "Australia/Sydney" }
        let water = makeHabit("Water", status: .habit) { $0.reminderTimes = [LocalTime("09:00")] }
        let (model, calendar) = try travelling([mum, water], from: "Australia/Sydney", at: beforeTheFlight, notifications: recorder)
        let moment = ISO8601.parse("2026-11-04T22:00:00Z")
        await model.parts.derived.publish()
        await model.waitForNotifications()
        #expect(try await planned("Call mum", by: recorder).fireDate == moment)

        calendar.fly(to: "Europe/Istanbul")
        await model.timeDidChange()
        await model.waitForNotifications()

        let ring = try await planned("Call mum", by: recorder)
        #expect(ring.isAbsolute)
        #expect(ring.fireDate == moment)
        #expect(try await planned("Water", by: recorder).fireDate == ISO8601.parse("2026-11-05T06:00:00Z"))
    }
}
