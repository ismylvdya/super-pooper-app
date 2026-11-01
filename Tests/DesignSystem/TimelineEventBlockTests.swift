import SwiftUI
import Testing
@testable import SuperPooperApp

/// An event's title and time sit at the top of its block (.26122): a tall block (a zoomed timeline) does not centre them,
/// and a block of the minimum height looks as before.
@MainActor
struct TimelineEventBlockTests {
    private let height = 300

    @Test func aTallEventShowsItsTitleAtTheTop() throws {
        let event = CalendarEvent(eventIdentifier: "standup", title: "Standup", start: TestCalendar.date(TestCalendar.wednesday, "10:00"),
                                  end: TestCalendar.date(TestCalendar.wednesday, "13:00"), isAllDay: false, calendarID: "demo",
                                  calendarTitle: "Demo", colorHex: "#000000")
        let slot = TimelineSlot(content: .event(event), start: event.start, end: event.end, isPast: false)
        let block = TimelineEventBlock(event: event, slot: slot, font: .body, lineHeight: 22)
            .frame(width: 200, height: CGFloat(height))
            .environment(\.colorScheme, .light)
        let inked = try RenderedAlpha(block).inkedRows(fromX: 20)
        let lowest = try #require(inked.max())
        #expect(lowest < height / 4, "the title and the time end in the top quarter, not around the middle")
    }

    /// Content shorter than its space stands at the top; taller (a block of the minimum height) is centred as it always
    /// was, so such blocks look as before.
    @Test func contentStandsAtTheTopUnlessItIsTallerThanItsSpace() throws {
        let tall = TopAlignedContent { Color.black.frame(height: 40) }.frame(width: 10, height: 100)
        #expect(try RenderedAlpha(tall).inkedRows() == Array(0..<40))
        let short = VStack(spacing: 0) {
            Color.clear.frame(height: 20)
            TopAlignedContent { Color.black.frame(height: 40) }.frame(height: 20)
            Color.clear.frame(height: 20)
        }
        .frame(width: 10)
        #expect(try RenderedAlpha(short).inkedRows() == Array(10..<50))
    }
}
