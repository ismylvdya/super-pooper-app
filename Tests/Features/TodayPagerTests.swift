import SwiftUI
import Testing
@testable import SuperPooperApp

/// Today's pages and days: a sideways drag moves the pages and turns them when it goes far enough; a vertical one never
/// does; there is nothing to turn to past the first or the last page or without pages.
@MainActor
struct TodayPagerTests {
    private let gestures = TestConfig.rules.gestures
    private let width: CGFloat = 400

    @Test func aLongSidewaysDragTurnsToTheNextPage() {
        let pager = TodayPager()
        pager.swipeChanged(CGSize(width: -10, height: 1), pageCount: 2, gestures: gestures)
        pager.swipeChanged(CGSize(width: -300, height: 5), pageCount: 2, gestures: gestures)
        #expect(pager.pageDrag == -300)
        pager.swipeEnded(CGSize(width: -300, height: 5), predicted: CGSize(width: -300, height: 5), containerWidth: width,
                         pageCount: 2, gestures: gestures, animation: .default)
        #expect(pager.page == 1)
        #expect(pager.pageDrag == 0)
    }

    @Test func aShortDragGoesBackAndAVerticalOneNeverMovesThePages() {
        let pager = TodayPager()
        pager.swipeChanged(CGSize(width: -20, height: 0), pageCount: 2, gestures: gestures)
        pager.swipeEnded(CGSize(width: -20, height: 0), predicted: CGSize(width: -20, height: 0), containerWidth: width,
                         pageCount: 2, gestures: gestures, animation: .default)
        #expect(pager.page == 0 && pager.pageDrag == 0)
        pager.swipeChanged(CGSize(width: 0, height: 30), pageCount: 2, gestures: gestures)
        pager.swipeChanged(CGSize(width: -300, height: 40), pageCount: 2, gestures: gestures)
        #expect(pager.pageDrag == 0, "the drag's direction was decided by its first movement")
        pager.swipeEnded(CGSize(width: -300, height: 40), predicted: CGSize(width: -300, height: 40), containerWidth: width,
                         pageCount: 2, gestures: gestures, animation: .default)
        #expect(pager.page == 0)
    }

    @Test func thereIsNoPagePastTheEndsOrWithoutPages() {
        let pager = TodayPager()
        pager.swipeChanged(CGSize(width: 300, height: 0), pageCount: 2, gestures: gestures)
        #expect(pager.pageDrag == 0, "nothing before the first page")
        pager.turn(to: 1, pageCount: 1, animation: .default)
        #expect(pager.page == 0, "a layout without pages")
        pager.turn(to: 1, pageCount: 2, animation: .default)
        #expect(pager.page == 1)
        pager.resetPage()
        #expect(pager.page == 0)
    }
}
