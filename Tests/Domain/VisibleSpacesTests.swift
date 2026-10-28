import Testing
@testable import SuperPooperApp

@Suite("Visible trailing spaces")
struct VisibleSpacesTests {
    @Test func noBreakSpacesAreStoredAsOrdinaryOnes() {
        #expect("word\u{00A0}".withOrdinarySpaces == "word ")
        #expect("two\u{00A0}words ".withOrdinarySpaces == "two words ")
        #expect("plain".withOrdinarySpaces == "plain")
    }
}
