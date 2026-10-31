import Foundation
import Testing
@testable import SuperPooperApp

/// Which occurrence of a repeating event an alert's "Delete event" means.
struct EventOccurrenceTests {
    private let context = TestCalendar.context()
    private let wednesday = makeEvent("Standup", from: "10:00", to: "10:15", id: "standup")
    private let thursday = makeEvent("Standup", day: "2026-10-22", from: "10:00", to: "10:15", id: "standup")

    private func find(_ start: Date, in events: [CalendarEvent]) -> CalendarEvent? {
        EventOccurrence.find(identifier: "standup", start: start, in: events, context: context)
    }

    @Test func theOccurrenceOfTheAlertsDay() {
        #expect(find(thursday.start, in: [wednesday, thursday]) == thursday)
    }

    @Test func anOccurrenceMovedWithinItsDayIsStillFound() {
        let moved = makeEvent("Standup", day: "2026-10-22", from: "11:30", to: "11:45", id: "standup")
        #expect(find(thursday.start, in: [wednesday, moved]) == moved)
    }

    /// The bug: Thursday's alert, with Thursday's occurrence gone, deleted Wednesday's (the first with that identifier).
    @Test func anotherDaysOccurrenceIsNeverTaken() {
        #expect(find(thursday.start, in: [wednesday]) == nil)
    }

    @Test func anOccurrenceAfterMidnightBelongsToTheDayBefore() {
        let late = makeEvent("Standup", day: "2026-10-22", from: "01:00", to: "01:30", id: "standup")
        #expect(find(TestCalendar.date(TestCalendar.wednesday, "23:30"), in: [late, thursday]) == late)
    }
}
