import Foundation
import Testing
@testable import SuperPooperApp

/// The bell on the timeline marks only events with a Calendar alert: every timed task, repeatable task and habit of today
/// stands on the timeline and rings at the time it stands at, so a bell would tell nothing about them.
/// Wednesday 2026-10-21, now 08:00.
@Suite("Timeline bell and notifications")
struct TimelineBellTests {
    private let morning = TestCalendar.context(TestCalendar.wednesday, "08:00")
    private let planner = NotificationPlanner(horizonDays: TestConfig.rules.notifications.horizonDays,
                                              limit: TestConfig.rules.notifications.limit)
    private let task = makeTask("Call the bank") { $0.due = TaskDue("2026-10-21T10:00") }
    private let habit = makeHabit("Vitamins", time: "09:00")
    private let repeatable = makeHabit("Water the plants", time: "18:00") { $0.habit.repeatable = true }

    private func alerting(_ title: String, alarm: Bool) -> CalendarEvent {
        var event = makeEvent(title, from: "12:00", to: "13:00")
        event.hasAlarm = alarm
        event.alarmDates = alarm ? [TestCalendar.date(TestCalendar.wednesday, "11:50")] : []
        return event
    }

    private func title(_ content: TimelineContent) -> String {
        switch content {
        case .event(let event): event.title
        case .task(let item): item.id
        case .reminder(let reminder): reminder.title
        }
    }

    @Test func onlyAnEventWithAnAlertShowsTheBell() throws {
        let plan = DayScenario(tasks: [task, habit, repeatable],
                               events: [alerting("Standup", alarm: true), alerting("Lunch", alarm: false)],
                               reminders: [makeReminder("Pay rent", at: "15:00")]).build(at: morning)
        let bells = Dictionary(plan.timeline.map { (title($0.content), $0.showsBell) }, uniquingKeysWith: { first, _ in first })
        #expect(bells == ["Standup": true, "Lunch": false, "Pay rent": false, "Call the bank": false, "Vitamins": false,
                          "Water the plants": false])
    }

    /// Whatever kind it is, a timed block of today rings at the moment it starts on the timeline.
    @Test func everyTimedBlockOfTodayRingsAtItsStart() {
        let tasks = [task, habit, repeatable]
        let plan = DayScenario(tasks: tasks).build(at: morning)
        let planned = planner.plan(tasks: tasks, reminders: [], skipped: [], context: morning).filter { $0.day == morning.today }
        let blocks = plan.timeline.compactMap { slot -> String? in
            guard case .task(let item) = slot.content else { return nil }
            return "\(item.id) \(clockTime(slot.start))"
        }
        #expect(blocks.count == 3)
        #expect(Set(blocks) == Set(planned.compactMap { note in note.taskName.map { "\($0) \(clockTime(note.fireDate))" } }))
    }
}
