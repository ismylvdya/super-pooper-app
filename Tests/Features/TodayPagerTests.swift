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

    /// The Tasks tab and the day's name bring back today on the pool's page.
    @Test func theTasksTabAndTheDayTitleBringBackThePoolOfToday() {
        let pager = TodayPager()
        pager.turn(to: 1, pageCount: 2, animation: .default)
        pager.changeDay(by: 1, width: width, duration: 0)
        pager.showPool(animation: .default)
        #expect(pager.page == 0 && pager.dayOffset == 0)
        pager.showPool(poolBlock: 1, animation: .default)
        #expect(pager.page == 1, "a layout whose pool is its second page")
    }

    private func pulled(_ pager: TodayPager, _ x: CGFloat, backlog: Int = 3) -> Bool {
        pager.swipeChanged(CGSize(width: x, height: 0), containerWidth: width, pageCount: 2 + pager.openedBacklog,
                           backlogCount: backlog, gestures: gestures)
    }

    private func released(_ pager: TodayPager, _ x: CGFloat, backlog: Int = 3) -> Bool {
        pager.swipeEnded(CGSize(width: x, height: 0), predicted: CGSize(width: x, height: 0), containerWidth: width,
                         pageCount: 2 + pager.openedBacklog, backlogCount: backlog, gestures: gestures, duration: 0)
    }

    /// The first page pulled right follows the finger with a scroll view's resistance; past the threshold it arms once
    /// (the moment to feel), and letting go opens the next list at index 0, where the page shown was.
    @Test func pullingTheFirstPageRightPastTheThresholdOpensTheNextList() {
        let pager = TodayPager()
        #expect(!pulled(pager, 30))
        let stretched = PullArming.stretch(30, dimension: width, resistance: gestures.pullResistance)
        #expect(pager.sidePull == stretched && pager.page == 0 && pager.pageDrag == 0)
        #expect(stretched < 30, "the pull resists the finger")
        #expect(pulled(pager, 320), "armed")
        #expect(!pulled(pager, 340), "armed once")
        #expect(released(pager, 340))
        #expect(pager.openedBacklog == 3 && pager.page == 2 && pager.sidePull == 0, "the nearest list, with the others left of it")
        #expect(pulled(pager, 320), "a list opens the next one by the same pull")
        #expect(pager.page == 2 && pager.pageDrag == 0, "the pull turns nothing")
        #expect(released(pager, 320))
        #expect(pager.reachedBacklog == 2 && pager.page == 1)
        #expect(pulled(pager, 320))
        #expect(released(pager, 320))
        #expect(pager.reachedBacklog == 3 && pager.page == 0)
    }

    /// A short pull from a list leaves it where it is, and a list already reached turns by a plain swipe.
    @Test func aListNotReachedYetOpensOnlyByAPull() {
        let pager = TodayPager()
        _ = pulled(pager, 320)
        _ = released(pager, 320)
        _ = pulled(pager, 40)
        #expect(!released(pager, 40))
        #expect(pager.page == 2 && pager.reachedBacklog == 1, "still Soon")
        _ = pulled(pager, 320)
        _ = released(pager, 320)
        pager.turn(to: 2, pageCount: 5, animation: .default)
        #expect(!pulled(pager, 150), "Half year is reached: a swipe, not a pull")
        #expect(pager.pageDrag == 150 && pager.sidePull == 0)
    }

    /// While a drag goes sideways the lists do not scroll; a drag that went up or down keeps them scrolling, and the lock
    /// goes with the finger, also when the gesture never ends.
    @Test func aSidewaysSwipeLocksScrollingUntilTheFingerIsGone() {
        let pager = TodayPager()
        changed(pager, -40)
        #expect(pager.isSwipingSideways)
        ended(pager, -40)
        #expect(!pager.isSwipingSideways)
        changed(pager, 0, 40)
        #expect(!pager.isSwipingSideways)
        ended(pager, 0, 40)
        changed(pager, -40)
        pager.endSwipe()
        #expect(!pager.isSwipingSideways && pager.pageDrag == 0)
    }

    /// Reached by a dragged task or a tap on its edge, a list counts as reached.
    @Test func aListTurnedToIsReached() {
        let pager = TodayPager()
        _ = pulled(pager, 320)
        _ = released(pager, 320)
        pager.turn(to: 0, pageCount: 5, animation: .default)
        #expect(pager.reachedBacklog == 3)
    }

    @Test func aShortPullOpensNothingAndAllListsOpenedPullsNoMore() {
        let pager = TodayPager()
        _ = pulled(pager, 40)
        #expect(!released(pager, 40))
        #expect(pager.openedBacklog == 0 && pager.sidePull == 0)
        for _ in 0..<3 {
            _ = pulled(pager, 320)
            _ = released(pager, 320)
        }
        #expect(pager.openedBacklog == 3 && pager.page == 0)
        #expect(!pulled(pager, 320))
        #expect(pager.sidePull == 0, "nothing left to open")
        #expect(!released(pager, 320))
        #expect(pager.openedBacklog == 3)
    }

    /// A pull brought back under half of the threshold before letting go opens nothing; a pull that turns into a leftward
    /// drag turns the page instead.
    @Test func aPullTakenBackOpensNothing() {
        let pager = TodayPager()
        _ = pulled(pager, 320)
        _ = pulled(pager, 10)
        #expect(!released(pager, 10))
        #expect(pager.openedBacklog == 0)
        _ = pulled(pager, 320)
        _ = pulled(pager, -150)
        #expect(pager.sidePull == 0 && pager.pageDrag == -150)
        #expect(!released(pager, -150))
        #expect(pager.page == 1 && pager.openedBacklog == 0)
    }

    /// Opened pages are free to turn between; another tab forgets them and shows the pool's page.
    @Test func leavingTheTabForgetsTheLeftPages() {
        let pager = TodayPager()
        _ = pulled(pager, 320)
        _ = released(pager, 320)
        changed(pager, -10)
        ended(pager, -150)
        #expect(pager.page == 2, "Soon stays: the helper counts two pages")
        pager.closeBacklog()
        #expect(pager.openedBacklog == 0 && pager.page == 0)
        _ = pulled(pager, 320)
        _ = released(pager, 320)
        pager.closeBacklog(poolBlock: 0)
        #expect(pager.openedBacklog == 0 && pager.page == 0)
    }

    /// The day's name goes back to the pool and keeps the opened pages; the Tasks tab forgets them.
    @Test func theTasksTabForgetsTheLeftPagesTheDayNameKeepsThem() {
        let pager = TodayPager()
        _ = pulled(pager, 320)
        _ = released(pager, 320)
        pager.showPool(animation: .default)
        #expect(pager.openedBacklog == 3 && pager.page == 3, "the pool, the lists still left of it")
        pager.turn(to: 0, pageCount: 5, animation: .default)
        pager.showPool(forgetsBacklog: true, animation: .default)
        #expect(pager.openedBacklog == 0 && pager.reachedBacklog == 0 && pager.page == 0)
    }

    /// Lists with no pull (`needsPull` off): all of them stand open left of the pool from the start, the pool stays in
    /// sight, and another tab keeps them open.
    @Test func listsWithNoPullAreAllOpen() {
        let pager = TodayPager()
        pager.setFreeLists(3)
        #expect(pager.openedBacklog == 3 && pager.reachedBacklog == 3 && pager.page == 3)
        pager.closeBacklog(poolBlock: 0)
        #expect(pager.openedBacklog == 3 && pager.page == 3)
        pager.setFreeLists(0)
        #expect(pager.openedBacklog == 0 && pager.page == 0)
    }
}
