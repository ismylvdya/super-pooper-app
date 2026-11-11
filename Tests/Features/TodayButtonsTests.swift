import Testing
@testable import SuperPooperApp

/// Today's top: Lists on the left carries the problems badge, "…" on the right.
struct TodayButtonsTests {
    @Test func listsStandsLeftAndSearchRight() {
        #expect(TodayButtons.Placement.leading.items == [.lists])
        #expect(TodayButtons.Placement.trailing.items == [.more])
    }

    @Test func theBadgeShowsOnlyProblemsWhenTheFlagIsOn() {
        #expect(TodayButtons.badgeCount(problemCount: 3, flagOn: true) == 3)
        #expect(TodayButtons.badgeCount(problemCount: 0, flagOn: true) == nil)
        #expect(TodayButtons.badgeCount(problemCount: 3, flagOn: false) == nil)
    }
}
