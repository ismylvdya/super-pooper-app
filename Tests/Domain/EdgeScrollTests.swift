import Testing
@testable import SuperPooperApp

struct EdgeScrollTests {
    @Test func theBandsAtTheEdgesScrollTheList() {
        #expect(EdgeScroll.direction(y: 110, top: 100, bottom: 500, band: 52) == .up)
        #expect(EdgeScroll.direction(y: 300, top: 100, bottom: 500, band: 52) == .none)
        #expect(EdgeScroll.direction(y: 470, top: 100, bottom: 500, band: 52) == .down)
        #expect(EdgeScroll.direction(y: 90, top: 100, bottom: 500, band: 52) == .none, "outside the list it is not the list's")
    }

    @Test func itStopsAtEitherEnd() {
        #expect(EdgeScroll.offset(5, .up, step: 7, maximum: 300) == 0)
        #expect(EdgeScroll.offset(298, .down, step: 7, maximum: 300) == 300)
        #expect(EdgeScroll.offset(100, .down, step: 7, maximum: 300) == 107)
    }
}
