import Foundation
import Testing
@testable import SuperPooperApp

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

    private func clock(_ window: TimelineWindow) -> String { "\(clockTime(window.start))–\(clockTime(window.end))" }

    /// Hours around now stop at the logical day's end (04:00): the widget at 23:00 with eight hours after now shows the
    /// day up to its boundary, not empty hours of the next one.
    @Test func hoursAroundNowStopAtTheEndOfTheDay() {
        let context = TestCalendar.context(TestCalendar.wednesday, "23:00")
        let windows = TimelineWindow.windows(.aroundNow(hoursBefore: 2, hoursAfter: 8), around: context.now, context: context)
        #expect(windows.map(clock) == ["21:00–04:00"])
        let morning = TestCalendar.context(TestCalendar.wednesday, "05:00")
        #expect(TimelineWindow.windows(.aroundNow(hoursBefore: 2, hoursAfter: 3), around: morning.now, context: morning).map(clock)
                == ["04:00–08:00"])
    }

    @Test func aRangeAndHalvesKeepToTheDay() {
        let context = TestCalendar.context()
        let range = TimelineSpan.Range(start: LocalTime("06:00"), end: LocalTime("06:00"))
        #expect(TimelineWindow.windows(.range(range), around: context.now, context: context).map(clock) == ["06:00–04:00"])
        let halves = TimelineSpan.halves(.init(start: LocalTime("06:00"), end: LocalTime("14:00")),
                                         .init(start: LocalTime("14:00"), end: LocalTime("02:00")))
        #expect(TimelineWindow.windows(halves, around: context.now, context: context).map(clock) == ["06:00–14:00", "14:00–02:00"])
    }

    /// The widget's caps: fewer hours before now, and no more hours in all than it has room for.
    @Test func limitsCapTheHoursAroundNow() {
        let limits = TimelineSpan.Limits(hoursBefore: 1, hours: 6)
        #expect(TimelineSpan.aroundNow(hoursBefore: 3, hoursAfter: 10, limits: limits) == .aroundNow(hoursBefore: 1, hoursAfter: 5))
        #expect(TimelineSpan.aroundNow(hoursBefore: 3, hoursAfter: 10, limits: .init()) == .aroundNow(hoursBefore: 3, hoursAfter: 10))
        #expect(TimelineSpan.aroundNow(hoursBefore: 6, hoursAfter: 2, limits: .init(hours: 6)) == .aroundNow(hoursBefore: 6, hoursAfter: 1))
    }
}
