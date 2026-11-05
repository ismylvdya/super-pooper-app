import Foundation
import Testing
@testable import SuperPooperApp

/// An alarm's slider stops the ringing: its notification comes right after, and the task stays open and in its place.
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
        let planned = await recorder.lastPlanned
        #expect(planned.contains { $0.key == "task|Call" && $0.fireDate > model.clock.now }, "\(planned.map(\.key))")
        #expect(model.task(named: "Call")?.status == .thisWeek)
        #expect(model.task(named: "Call")?.due == TaskDue("2026-10-21T13:00"))
    }
}
