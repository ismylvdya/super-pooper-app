import Testing
@testable import SuperPooper

@Suite("Visible trailing spaces")
struct VisibleSpacesTests {
    @Test func trailingSpacesBecomeNoBreakSpaces() {
        #expect("word ".withVisibleTrailingSpaces == "word\u{00A0}")
        #expect("a  ".withVisibleTrailingSpaces == "a\u{00A0}\u{00A0}")
    }

    @Test func innerSpacesStayOrdinary() {
        #expect("two words ".withVisibleTrailingSpaces == "two words\u{00A0}")
        #expect("two words".withVisibleTrailingSpaces == "two words")
    }

    @Test func theStoredTextHasOrdinarySpacesAgain() {
        #expect("word\u{00A0}".withOrdinarySpaces == "word ")
        #expect("word ".withVisibleTrailingSpaces.withOrdinarySpaces == "word ")
    }
}
