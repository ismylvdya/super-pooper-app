import SwiftUI
import Testing
@testable import SuperPooperApp

/// The timeline leaves the all-day strip the room it reports; that must be the room it takes.
@MainActor
struct AllDayStripTests {
    @Test(arguments: [1, 3])
    func theHeightItReportsIsTheHeightItTakes(count: Int) {
        let tokens = TestConfig.tokens
        let start = Date(timeIntervalSince1970: 0)
        let events = (0..<count).map { index in
            CalendarEvent(eventIdentifier: "day\(index)", title: "Holiday \(index)", start: start, end: start.addingTimeInterval(86_400),
                          isAllDay: true, calendarID: "", calendarTitle: "", colorHex: "#FF0000")
        }
        let fonts = TimelineFonts.app(TestConfig.defaults.timeline, tokens: tokens)
        let strip = AllDayStrip(events: events, font: fonts.allDay, lineHeight: fonts.allDayLineHeight).environment(\.tokens, tokens)
        let measured = UIHostingController(rootView: strip).sizeThatFits(in: CGSize(width: 300, height: CGFloat.infinity)).height
        #expect(abs(measured - AllDayStrip.height(count: count, lineHeight: fonts.allDayLineHeight, tokens: tokens)) < 0.5)
    }

    @Test func theIconStandsOverTheMiddleOfTheHourNumbers() {
        let tokens = TestConfig.tokens
        let lineHeight: CGFloat = 16
        let iconCenter = AllDayStrip.leadingInset(lineHeight: lineHeight, tokens: tokens)
            + ChipCapsule.standard.verticalPadding(tokens) + lineHeight / 2
        #expect(abs(iconCenter - tokens.hourDigitsCenter) < 0.001)
    }

    @Test func noEventsTakeNoRoom() {
        #expect(AllDayStrip.height(count: 0, lineHeight: 20, tokens: TestConfig.tokens) == 0)
    }
}
