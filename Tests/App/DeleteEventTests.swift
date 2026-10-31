import Foundation
import Testing
@testable import SuperPooperApp

/// "Delete event" on an event alert deletes exactly the occurrence of that alert, or nothing.
@MainActor
struct DeleteEventTests {
    private let context = PreviewSamples.context

    private func standup(_ dayOffset: Int, at hour: Int) -> CalendarEvent {
        let start = context.date(context.today.adding(days: dayOffset), LocalTime(hour: hour, minute: 0) ?? .midnight)
        return CalendarEvent(eventIdentifier: "standup", title: "Standup", start: start, end: start.addingTimeInterval(900),
                             isAllDay: false, calendarID: "demo", calendarTitle: "Demo", colorHex: "#30B0C7")
    }

    private let events = RecordingEvents()

    private func model(with events: [CalendarEvent]) throws -> (AppModel, FakeCalendars) {
        let calendars = FakeCalendars(events: events)
        let model = try #require(PreviewModel.make(calendars: calendars, delay: NoDelay(), appEvents: self.events)).model
        return (model, calendars)
    }

    @Test func theAlertsOccurrenceIsDeleted() async throws {
        let (model, calendars) = try model(with: [standup(0, at: 10), standup(1, at: 10)])
        await model.parts.sources.refresh()
        await model.deleteEvent(identifier: "standup", start: standup(1, at: 10).start)
        #expect(calendars.deleted == [standup(1, at: 10)])
    }

    /// Moved within its day after the alert was planned: still that day's occurrence.
    @Test func anOccurrenceMovedWithinItsDayIsDeleted() async throws {
        let (model, calendars) = try model(with: [standup(0, at: 10), standup(1, at: 12)])
        await model.parts.sources.refresh()
        await model.deleteEvent(identifier: "standup", start: standup(1, at: 10).start)
        #expect(calendars.deleted == [standup(1, at: 12)])
    }

    /// The bug: with tomorrow's occurrence gone, its alert deleted today's (the first event with that identifier).
    @Test func withoutTheAlertsOccurrenceNothingIsDeleted() async throws {
        let (model, calendars) = try model(with: [standup(0, at: 10)])
        await model.parts.sources.refresh()
        await model.deleteEvent(identifier: "standup", start: standup(1, at: 10).start)
        #expect(calendars.deleted.isEmpty)
        #expect(events.sent == [.failure(.eventNotFound)])
    }

    /// An event not read yet (the alert came before the app read its calendars) is read and then found.
    @Test func anEventNotReadYetIsReadFirst() async throws {
        let (model, calendars) = try model(with: [standup(1, at: 10)])
        await model.deleteEvent(identifier: "standup", start: standup(1, at: 10).start)
        #expect(calendars.deleted == [standup(1, at: 10)])
    }
}
