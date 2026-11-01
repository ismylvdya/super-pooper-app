import Foundation
import Testing
@testable import SuperPooperApp

/// A link written with another identifier (the Claude skill) finds its event by title and a start within
/// `day.eventLinkToleranceSeconds`.
struct EventLinkResolverTests {
    private let call = makeEvent("Call with dad", from: "19:00", to: "20:00")

    private func resolve(_ link: EventLink, tolerance: TimeInterval) -> CalendarEvent? {
        EventLinkResolver(events: [call], calendar: TestCalendar.calendar, tolerance: tolerance).resolve(link)
    }

    @Test func aTitleLinkMatchesAStartWithinTheTolerance() {
        let link = EventLink(eventIdentifier: "skill", title: call.title, start: call.start.addingTimeInterval(50))
        #expect(resolve(link, tolerance: TestConfig.rules.day.eventLinkToleranceSeconds) == call)
        #expect(resolve(link, tolerance: 30) == nil)
    }

    @Test func anIdentifierLinkIgnoresTheToleranceOnItsDay() {
        let link = EventLink(eventIdentifier: call.eventIdentifier, title: "Renamed", start: call.start.addingTimeInterval(3600))
        #expect(resolve(link, tolerance: 0) == call)
    }
}
