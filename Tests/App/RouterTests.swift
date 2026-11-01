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
        let list = try routed("superpooper://lists/someday")
        #expect(list.tab == .lists && list.path == [.list("someday")])
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
        #expect(router.tab == .today && router.path == [.newTask])
    }

    @Test func unknownLinksOpenTodayAndOtherSchemesNothing() throws {
        let router = try routed("superpooper://habits")
        router.handle(try #require(URL(string: "https://example.com/task/X")))
        #expect(router.tab == .habits)
        router.handle(try #require(URL(string: "superpooper://nowhere")))
        #expect(router.tab == .today && router.path.isEmpty)
    }

    /// Tapping the open tab goes back to its first page; every tap on Today brings back today's date.
    @Test func tappingTheOpenTabGoesBackToItsFirstPage() {
        let router = Router()
        router.select(.habits)
        router.open(.routines)
        router.select(.today)
        #expect(router.paths[.habits] == [.routines])
        router.select(.habits)
        router.select(.habits)
        #expect(router.path.isEmpty)
        let taps = router.todayTaps
        router.select(.today)
        #expect(router.todayTaps == taps + 1)
    }
}
