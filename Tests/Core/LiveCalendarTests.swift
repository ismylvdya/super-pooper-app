import Foundation
import Testing
@testable import SuperPooperApp

/// The app calendar is built again when the phone's zone changes, instead of staying as it was at launch.
struct LiveCalendarTests {
    @Test func aRefreshPicksUpTheNewZone() {
        let calendar = TravellingCalendar("Asia/Jakarta")
        #expect(calendar.current.timeZone.identifier == "Asia/Jakarta")
        calendar.fly(to: "Europe/Belgrade")
        #expect(calendar.current.timeZone.identifier == "Europe/Belgrade")
    }

    @Test func aRefreshTellsWhetherAnythingChanged() {
        let live = LiveCalendar { TestCalendar.calendar }
        #expect(!live.refresh())
        #expect(live.current == TestCalendar.calendar)
    }
}
