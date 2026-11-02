import SwiftUI
import Testing
@testable import SuperPooperApp

/// Today's pages and days: a sideways drag moves the pages with the finger until it lifts, and only then do they settle:
/// turned past a quarter of the width or flung, back otherwise; a vertical one never moves them; there is nothing to turn to past the first
/// or the last page or without pages.
@MainActor
struct TodayPagerTests {
    private let gestures = TestConfig.rules.gestures
    private let width: CGFloat = 400

    private func changed(_ pager: TodayPager, _ x: CGFloat, _ y: CGFloat = 0) {
        pager.swipeChanged(CGSize(width: x, height: y), containerWidth: width, pageCount: 2, gestures: gestures)
    }

    private func ended(_ pager: TodayPager, _ x: CGFloat, _ y: CGFloat = 0, predicted: CGFloat? = nil) {
        pager.swipeEnded(CGSize(width: x, height: y), predicted: CGSize(width: predicted ?? x, height: y), containerWidth: width,
                         pageCount: 2, gestures: gestures, duration: 0.25)
    }

    @Test func aDragFollowsTheFingerUntilAQuarterOfTheWidth() {
        let pager = TodayPager()
        changed(pager, -10, 1)
        changed(pager, -90, 5)
        #expect(pager.pageDrag == -90 && pager.page == 0)
    }

    /// Past the threshold the page still follows the finger, and turns only once it lifts there; brought back under the
    /// threshold before lifting, it goes back.
    @Test func thePageSettlesOnlyOnceTheFingerLifts() {
        let pager = TodayPager()
        changed(pager, -10, 1)
        changed(pager, -110, 5)
        #expect(pager.page == 0 && pager.pageDrag == -110, "still under the finger")
        changed(pager, -20, 5)
        #expect(pager.page == 0 && pager.pageDrag == -20)
        ended(pager, -20, 5)
        #expect(pager.page == 0 && pager.pageDrag == 0)
        changed(pager, -10, 1)
        changed(pager, -110, 5)
        ended(pager, -110, 5)
        #expect(pager.page == 1 && pager.pageDrag == 0)
    }

    @Test func theTurnStartsAtTheFingersSpeed() {
        #expect(TodaySwipe.initialVelocity(speed: -600, remaining: 300) == 2)
        #expect(TodaySwipe.initialVelocity(speed: 600, remaining: 0) == 0)
    }

    @Test func aShortDragGoesBackAFlingTurnsAndAVerticalOneNeverMovesThePages() {
        let pager = TodayPager()
        changed(pager, -20)
        ended(pager, -20)
        #expect(pager.page == 0 && pager.pageDrag == 0)
        changed(pager, 0, 30)
        changed(pager, -300, 40)
        #expect(pager.pageDrag == 0, "the drag's direction was decided by its first movement")
        ended(pager, -300, 40)
        #expect(pager.page == 0)
        changed(pager, -40)
        ended(pager, -40, predicted: -260)
        #expect(pager.page == 1, "flung past half the width")
    }

    @Test func thereIsNoPagePastTheEndsOrWithoutPages() {
        let pager = TodayPager()
        changed(pager, 300)
        #expect(pager.pageDrag == 0, "nothing before the first page")
        pager.turn(to: 1, pageCount: 1, animation: .default)
        #expect(pager.page == 0, "a layout without pages")
        pager.turn(to: 1, pageCount: 2, animation: .default)
        #expect(pager.page == 1)
        pager.resetPage()
        #expect(pager.page == 0)
    }
}
