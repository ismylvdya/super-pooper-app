import Foundation
import Testing
@testable import SuperPooperApp

/// A zoomed-in timeline shows finer marks (.26423): ":15", ":30", ":45" fade in on the way to about five visible hours, a
/// line every five minutes on the way to about two; zoomed out they are gone. The thresholds are `rules.json`'s.
struct TimelineGridDetailTests {
    private let rules = TestConfig.rules.timeline.detail

    @Test func theConfigFadesQuartersInByFiveHoursAndFineLinesByTwo() {
        #expect(rules.quarters.fullAtHours == 5)
        #expect(rules.fiveMinutes.fullAtHours == 2)
        #expect(TestConfig.rules.timeline.quarterMinutes == 15)
        #expect(TestConfig.rules.timeline.fineLineMinutes == 5)
    }

    @Test func zoomedOutThereAreNoFinerMarks() {
        #expect(TimelineGridDetail(visibleHours: 10, rules: rules) == .none)
    }

    /// Through the fade range the opacity grows smoothly with the zoom, and stays full beyond it.
    @Test func quartersFadeInSmoothlyOnTheWayToFiveHours() {
        let fade = rules.quarters
        let middle = (fade.hiddenAboveHours + fade.fullAtHours) / 2
        #expect(fade.opacity(visibleHours: fade.hiddenAboveHours) == 0)
        #expect(abs(fade.opacity(visibleHours: middle) - 0.5) < 0.001)
        #expect(fade.opacity(visibleHours: fade.fullAtHours) == 1)
        let atFive = TimelineGridDetail(visibleHours: 5, rules: rules)
        #expect(atFive.quarters == 1)
        #expect(atFive.fiveMinutes == 0, "five-minute lines wait for a closer zoom")
    }

    @Test func atTwoHoursFiveMinuteLinesAreFullyIn() {
        let atTwo = TimelineGridDetail(visibleHours: 2, rules: rules)
        #expect(atTwo == TimelineGridDetail(quarters: 1, fiveMinutes: 1))
    }

    @Test func theMarksArePastEachHourButNotOnIt() {
        #expect(TimelineGridDetail.minutes(every: 15) == [15, 30, 45])
        #expect(TimelineGridDetail.minutes(every: 5).count == 11)
        #expect(TimelineGridDetail.minutes(every: 0).isEmpty)
    }

    /// The pinch reaches close enough for the five-minute lines on a phone's full-height timeline.
    @Test func theZoomReachesTwoHoursOnAPhone() {
        let fullHeight = 700.0
        let closest = fullHeight / (TestConfig.tokens.size(.hourHeight) * TestConfig.rules.timeline.zoom.max)
        #expect(closest <= rules.fiveMinutes.fullAtHours)
    }
}
