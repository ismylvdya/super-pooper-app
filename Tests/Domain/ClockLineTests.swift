import Foundation
import Testing
@testable import SuperPooperApp

@Suite("Clock line and tag emoji")
struct ClockLineTests {
    private let moscow = TimeZone(identifier: "Europe/Moscow")!

    @Test func timeIsShownInTheChosenZone() {
        // 13:25 in Belgrade (UTC+2 in October) is 14:25 in Moscow.
        #expect(ClockLine.text(prefix: "MSK ", date: TestCalendar.date(TestCalendar.wednesday, "13:25"), timeZone: moscow) == "MSK 14:25")
    }

    @Test func escapedCharactersAreDecoded() {
        #expect(ClockLine.decode("\\u{2800}a") == "\u{2800}a")
        #expect(ClockLine.decode("U+2800 b") == "\u{2800} b")
        #expect(ClockLine.decode("plain") == "plain")
        #expect(ClockLine.decode("U+12") == "U+12")
    }

    @Test func tagEmojiIsTheLeadingSymbol() {
        #expect(TagEmoji.leading(of: "🔫делишка") == "🔫")
        #expect(TagEmoji.leading(of: "#🔫делишка") == "🔫")
        #expect(TagEmoji.leading(of: "task") == nil)
    }
}
