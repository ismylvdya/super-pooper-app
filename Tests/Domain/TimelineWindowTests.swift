import Foundation
import Testing
@testable import SuperPooper

/// Hour heights and positions on a timeline column: one rule for the app, the settings preview and widgets.
struct TimelineWindowTests {
    private let start = TestCalendar.date(TestCalendar.wednesday, "08:00")

    @Test func aWindowIsFittedIntoAHeightHourByHour() {
        let window = TimelineWindow(start: start, end: start.addingTimeInterval(4 * TimelineWindow.hour))
        #expect(window.hours == 4)
        #expect(window.hourHeight(fitting: 200) == 50)
    }

    @Test func aWindowShorterThanAnHourIsScaledAsOneHour() {
        let window = TimelineWindow(start: start, end: start.addingTimeInterval(TimelineWindow.hour / 2))
        #expect(window.hourHeight(fitting: 80) == 80)
    }

    @Test func aMomentIsPlacedByItsDistanceFromTheStart() {
        let window = TimelineWindow(start: start, end: start.addingTimeInterval(10 * TimelineWindow.hour))
        #expect(window.offset(of: TestCalendar.date(TestCalendar.wednesday, "09:30"), hourHeight: 80) == 120)
    }
}
