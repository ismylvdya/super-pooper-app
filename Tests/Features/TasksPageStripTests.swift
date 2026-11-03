import Testing
@testable import SuperPooperApp

/// The pages of Tasks: the opened backlog pages, farthest first, then the day's pages.
struct TasksPageStripTests {
    private let lists = [
        BacklogList(id: "thisWeek", title: "status.thisWeek", icon: .listThisWeek, status: .thisWeek),
        BacklogList(id: "halfYear", title: "status.halfYear", icon: .listHalfYear, status: .halfYear),
        BacklogList(id: "someday", title: "status.someday", icon: .listSomeday, status: .someday),
    ]
    private let paged = TestConfig.decode(ScreenLayout.self, "layouts/today-paged.layout.json")
    private let stacked = TestConfig.decode(ScreenLayout.self, "layouts/today-stacked.layout.json")

    @Test func pagedTodayHasTheBacklogLeftOfThePool() {
        #expect(TasksPageStrip.pages(layout: paged, opened: 2, backlog: lists)
            == [.backlog("halfYear"), .backlog("thisWeek"), .block(.pool), .block(.timeline)])
        #expect(TasksPageStrip.homeIndex(layout: paged, opened: 2) == 2)
        #expect(TasksPageStrip.pages(layout: paged, opened: 0, backlog: lists) == [.block(.pool), .block(.timeline)])
    }

    @Test func otherLayoutsHaveTheBacklogLeftOfAllOfToday() {
        #expect(TasksPageStrip.pages(layout: stacked, opened: 1, backlog: lists) == [.backlog("thisWeek"), .today])
        #expect(TasksPageStrip.homeIndex(layout: stacked, opened: 1) == 1)
    }

    /// A drag asking for the pool or the timeline finds Today's one page when the layout is not paged.
    @Test func aBlockIsOnTodaysPageWithoutPages() {
        let pages = TasksPageStrip.pages(layout: stacked, opened: 2, backlog: lists)
        #expect(TasksPageStrip.index(of: .block(.timeline), in: pages) == 2)
        #expect(TasksPageStrip.index(of: .backlog("halfYear"), in: pages) == 0)
        #expect(TasksPageStrip.index(of: .backlog("someday"), in: pages) == nil)
    }
}
