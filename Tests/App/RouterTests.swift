import Foundation
import Testing
@testable import SuperPooperApp

/// Deep links (`superpooper://…`, also the Home Screen quick action) and the tab bar.
@MainActor
struct RouterTests {
    private func routed(_ link: String) throws -> Router {
        let router = Router()
        router.handle(try #require(URL(string: link)))
        return router
    }

    @Test func linksOpenTheirTabAndPage() throws {
        let task = try routed("superpooper://task/%D0%A1%D0%B4%D0%B0%D1%82%D1%8C%20%D0%BE%D1%82%D1%87%D1%91%D1%82")
        #expect(task.tab == .today && task.path == [.task("Сдать отчёт")])
        let habit = try routed("superpooper://habit/Water")
        #expect(habit.tab == .habits && habit.path == [.task("Water")])
        #expect(try routed("superpooper://habits").tab == .habits)
        #expect(try routed("superpooper://clock").tab == .settings)
        #expect(try routed("superpooper://archive").path == [.archive])
        #expect(try routed("superpooper://trash").path == [.trash])
    }

    @Test func reviewAndNewTaskLinks() throws {
        let review = try routed("superpooper://review")
        #expect(review.tab == .today && review.isReviewPresented)
        let router = try routed("superpooper://review")
        router.handle(try #require(URL(string: "superpooper://new-task")))
        #expect(!router.isReviewPresented)
        #expect(router.tab == .today && router.path == [.newItem(NewItemSeed(kind: .task))])
    }

    @Test func theTabBarHasTasksHabitsAndSettings() {
        #expect(AppTab.allCases == [.today, .habits, .settings])
    }

    @Test func plusOpensAHabitInHabitsAndATaskElsewhere() {
        #expect(NewItemSeed.opening(on: .habits).kind == .habit)
        #expect(NewItemSeed.opening(on: .today).kind == .task && NewItemSeed.opening(on: .settings).kind == .task)
        let router = Router()
        router.select(.settings)
        router.openNewItem()
        #expect(router.path == [.newItem(NewItemSeed(kind: .task))])
        router.select(.habits)
        router.openNewItem()
        #expect(router.path == [.newItem(NewItemSeed(kind: .habit))])
        router.openNewItem(NewItemSeed(kind: .task))
        #expect(router.path.last == .newItem(NewItemSeed(kind: .task)))
    }

    @Test func listsLinksOpenTheListsPageOnTasks() throws {
        let list = try routed("superpooper://lists/someday")
        #expect(list.tab == .today && list.path == [.lists, .list("someday")])
        #expect(try routed("superpooper://lists").path == [.lists])
    }

    @Test func unknownLinksOpenTodayAndOtherSchemesNothing() throws {
        let router = try routed("superpooper://habits")
        router.handle(try #require(URL(string: "https://example.com/task/X")))
        #expect(router.tab == .habits)
        router.handle(try #require(URL(string: "superpooper://nowhere")))
        #expect(router.tab == .today && router.path.isEmpty)
    }

    /// Tapping the open tab goes back to its first page; every tap on Tasks brings back today's pool.
    @Test func tappingTheOpenTabGoesBackToItsFirstPage() {
        let router = Router()
        router.select(.habits)
        router.open(.routines)
        router.select(.today)
        #expect(router.paths[.habits] == [.routines])
        router.select(.habits)
        router.select(.habits)
        #expect(router.path.isEmpty)
        let taps = router.tasksTaps
        router.select(.today)
        #expect(router.tasksTaps == taps + 1)
    }

    /// On Today with a page open further in, the Today tab goes back to its first page; from another tab Today's pages
    /// are found as they were left.
    @Test func theTodayTabClosesTodaysPagesOnlyFromToday() {
        let router = Router()
        router.open(.task("Report"))
        router.select(.habits)
        router.select(.today)
        #expect(router.path == [.task("Report")])
        router.select(.today)
        #expect(router.path.isEmpty)
    }
}
