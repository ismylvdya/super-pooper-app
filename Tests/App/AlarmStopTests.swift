import Foundation
import Testing
@testable import SuperPooperApp

/// An alarm's slider (or the cross on its banner) stops the ringing: its notification is shown right away, and the task
/// stays open and in its place. A moment seconds ahead would not do: a trigger keeps only minutes.
@MainActor
struct AlarmStopTests {
    @Test func theSliderLeavesANotificationAndTheTaskOpen() async throws {
        let recorder = RecordingNotifications()
        let task = makeTask("Call") {
            $0.due = TaskDue("2026-10-21T13:00")
            $0.alarms = [TimeAlarm()]
        }
        let model = try #require(PreviewModel.make(notifications: recorder,
                                                   calendar: FixedCalendar(current: TestCalendar.calendar),
                                                   clock: FixedClock(now: TestCalendar.date(TestCalendar.wednesday, "13:25")),
                                                   tasks: [task])).model
        await model.ensureLoaded()
        await model.alarmStopped(key: "task|Call", day: LocalDate(TestCalendar.wednesday))
        await model.waitForNotifications()
        // Shown once, right away; the plans after it do not show it again.
        await model.sync(announce: false)
        await model.waitForNotifications()
        let log = await recorder.log
        #expect(log.filter { $0.hasSuffix(" now task|Call") }.count == 1, "\(log)")
        #expect(log.last == "sync", "\(log)")
        #expect(model.task(named: "Call")?.status == .thisWeek)
        #expect(model.task(named: "Call")?.due == TaskDue("2026-10-21T13:00"))
    }

    /// Snooze on a ringing alarm brings no notification: the alarm itself rings again after the set minutes.
    @Test func snoozeRingsAgainWithoutANotification() async throws {
        let recorder = RecordingNotifications()
        let alarms = RecordingAlarms()
        let task = makeTask("Call") {
            $0.due = TaskDue("2026-10-21T13:00")
            $0.alarms = [TimeAlarm()]
        }
        let now = TestCalendar.date(TestCalendar.wednesday, "13:00")
        let model = try #require(PreviewModel.make(notifications: recorder,
                                                   calendar: FixedCalendar(current: TestCalendar.calendar),
                                                   clock: FixedClock(now: now), tasks: [task], alarms: alarms)).model
        await model.ensureLoaded()
        await model.snoozeNotification(key: "task|Call", day: LocalDate(TestCalendar.wednesday), shown: "")
        await model.waitForNotifications()
        let minutes = Double(model.settings.notifications.snoozeMinutes)
        let set = await alarms.lastSet
        #expect(set.map(\.fireDate) == [now.addingTimeInterval(minutes * 60)], "\(set)")
        let log = await recorder.log
        #expect(!log.contains { $0.contains(" now ") }, "\(log)")
        #expect(await !recorder.lastPlanned.contains { $0.key == "task|Call" })
    }
}
