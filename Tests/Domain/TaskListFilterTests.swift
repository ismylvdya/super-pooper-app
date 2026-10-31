import Foundation
import Testing
@testable import SuperPooperApp

/// The lists of the Lists tab: filters over all tasks, grouped by planning level.
struct TaskListFilterTests {
    private let rules = TestConfig.rules.day
    private let tasks = [
        makeTask("Read a novel", status: .someday) { $0.feel = .pleasant; $0.timeEstimate = 240 },
        makeTask("Paint the door", status: .halfYear) { $0.feel = .needEnergy },
        makeTask("Reply to Anna") { $0.timeEstimate = 2 },
        makeTask("Wait for the plumber", status: .waiting),
        makeTask("Old one", status: .done),
        makeHabit("Water", status: .habit),
    ]

    @Test func theWeeklyReviewHoldsWhatIsNotThisWeekYet() {
        let review = TaskListFilter(statuses: [.halfYear, .someday, .waiting])
        let groups = review.groups(of: tasks, query: "", rules: rules)
        #expect(groups.map(\.status) == [.halfYear, .someday, .waiting])
        #expect(groups.flatMap(\.tasks).map(\.name) == ["Paint the door", "Read a novel", "Wait for the plumber"])
    }

    @Test func propertyListsPickTheirTasks() {
        #expect(TaskListFilter(feel: .pleasant).groups(of: tasks, query: "", rules: rules).flatMap(\.tasks).map(\.name) == ["Read a novel"])
        #expect(TaskListFilter(feel: .needEnergy).groups(of: tasks, query: "", rules: rules).flatMap(\.tasks).map(\.name) == ["Paint the door"])
        let quick = TaskListFilter(maxEstimate: 15).groups(of: tasks, query: "", rules: rules).flatMap(\.tasks).map(\.name)
        #expect(quick == ["Reply to Anna", "Paint the door", "Wait for the plumber"])
    }

    @Test func allOpenTasksWithoutHabitsAndDoneOnesAndSearch() {
        let all = TaskListFilter().groups(of: tasks, query: "", rules: rules).flatMap(\.tasks).map(\.name)
        #expect(Set(all) == ["Read a novel", "Paint the door", "Reply to Anna", "Wait for the plumber"])
        #expect(TaskListFilter().groups(of: tasks, query: "PAINT", rules: rules).flatMap(\.tasks).map(\.name) == ["Paint the door"])
    }

    /// Done tasks go to the done folder at once: the Done list counts and shows those too, and is not "No tasks here"
    /// while it has them; other lists leave the folder out.
    @Test func theDoneListHoldsTheDoneFolder() {
        let filed = [
            makeTask("Filed earlier", status: .done) { $0.completedDate = LocalDate("2026-10-19") },
            makeTask("Filed today", status: .done) { $0.completedDate = LocalDate("2026-10-21") },
        ]
        let done = TaskListFilter(statuses: [.done])
        let contents = done.contents(of: tasks.filter { $0.status != .done }, filed: filed, query: "", rules: rules)
        #expect(!contents.isEmpty)
        #expect(contents.count == 2)
        #expect(contents.filed.map(\.name) == ["Filed today", "Filed earlier"])
        #expect(done.contents(of: [], filed: filed, query: "earlier", rules: rules).count == 1)
        #expect(TaskListFilter(statuses: [.someday]).contents(of: tasks, filed: filed, query: "", rules: rules).filed.isEmpty)
    }

    /// A list of one planning level says it in its title; a list of several titles each group by its level.
    @Test func onlyAListOfSeveralLevelsNamesThem() {
        #expect(TaskListFilter(statuses: [.someday]).contents(of: tasks, filed: [], query: "", rules: rules).namesLevels == false)
        #expect(TaskListFilter().contents(of: tasks, filed: [], query: "", rules: rules).namesLevels)
    }
}
