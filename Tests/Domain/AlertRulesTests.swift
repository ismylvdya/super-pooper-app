import Foundation
import Testing
@testable import SuperPooperApp

/// Event alerts, moves and the habit slot identifiers (today = Wednesday 2026-10-21).
@Suite("Alert rules")
struct AlertRulesTests {
    private let planner = NotificationPlanner(horizonDays: 2, limit: 64)

    private func event(_ start: String, alarmMinutes: Int = -10, id: String = "call") -> CalendarEvent {
        var event = makeEvent("Call", from: start, to: "20:00", id: id)
        event.alarmDates = [event.start.addingTimeInterval(Double(alarmMinutes) * 60)]
        event.hasAlarm = true
        return event
    }

    @Test func eventAlertsAreScheduledAtTheirTime() {
        let planned = planner.plan(tasks: [], reminders: [], events: [event("19:00")], skipped: [],
                                   context: TestCalendar.context(TestCalendar.wednesday, "08:00"))
        #expect(planned.map { clockTime($0.fireDate) } == ["18:50"])
        #expect(planned.first?.kind == .event)
    }

    @Test func aMovedEventGetsANewIdentifierAndKeepsItsKey() {
        let context = TestCalendar.context(TestCalendar.wednesday, "08:00")
        let before = planner.plan(tasks: [], reminders: [], events: [event("19:00")], skipped: [], context: context)
        let after = planner.plan(tasks: [], reminders: [], events: [event("19:30")], skipped: [], context: context)
        #expect(before.first?.id != after.first?.id)
        #expect(before.first?.key == after.first?.key)
        // The old one is no longer valid, so a delivered one is removed.
        let valid = planner.stillValidToday(tasks: [], reminders: [], events: [event("19:30")], skipped: [], context: context)
        #expect(!valid.contains { $0.id == before.first?.id })
    }

    @Test func anAlertMovedIntoThePastComesRightAway() {
        let now = TestCalendar.context(TestCalendar.wednesday, "18:55")
        let moved = planner.all(tasks: [], reminders: [], events: [event("19:00", alarmMinutes: -30)], skipped: [], context: now)
        let pending = [moved[0].key: TestCalendar.date(TestCalendar.wednesday, "19:20")]
        let late = LateAlerts.due(moved, pending: pending, known: [moved[0].key], now: now.now, calendar: TestCalendar.calendar)
        #expect(late.map(\.key) == [moved[0].key])
    }

    @Test func anAlertThatAlreadyFiredIsNotRepeated() {
        let now = TestCalendar.context(TestCalendar.wednesday, "18:55")
        let alerts = planner.all(tasks: [], reminders: [], events: [event("19:00")], skipped: [], context: now)
        let pending = [alerts[0].key: alerts[0].fireDate]
        #expect(LateAlerts.due(alerts, pending: pending, known: [alerts[0].key], now: now.now, calendar: TestCalendar.calendar).isEmpty)
    }

    @Test func anAlertAddedToAStartedEventComesOnceButNotOnTheFirstSync() {
        let now = TestCalendar.context(TestCalendar.wednesday, "19:10")
        let alerts = planner.all(tasks: [], reminders: [], events: [event("19:00")], skipped: [], context: now)
        #expect(LateAlerts.due(alerts, pending: [:], known: [], now: now.now, calendar: TestCalendar.calendar).count == 1)
        #expect(LateAlerts.due(alerts, pending: [:], known: nil, now: now.now, calendar: TestCalendar.calendar).isEmpty)
    }

    @Test func aHabitsNextNotificationReusesItsSlot() {
        let habit = makeHabit("Push-ups", status: .habit) { $0.reminderTimes = [LocalTime("21:00")] }
        let planned = planner.plan(tasks: [habit], reminders: [], skipped: [], context: TestCalendar.context(TestCalendar.wednesday, "22:00"))
        // Today's 21:00 is over: tomorrow's takes the slot identifier and replaces today's delivered one.
        #expect(planned.first?.id == NotificationPlanner.habitSlot("Push-ups", LocalTime("21:00")))
        #expect(planned.first?.day == LocalDate("2026-10-22"))
        #expect(planned.dropFirst().allSatisfy { $0.id != planned.first?.id })
    }
}
