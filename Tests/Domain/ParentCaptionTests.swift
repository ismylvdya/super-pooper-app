import Foundation
import Testing
@testable import SuperPooperApp

/// A subtask shown without its parent says the parent's name over its own: in the pool, the morning review, the lists
/// and the search. With its parent beside it, it sits under it on a line instead.
@Suite("Parent caption")
struct ParentCaptionTests {
    private let today = TaskDue(day: LocalDate(TestCalendar.wednesday))

    @Test func aSubtaskAloneInThePoolNamesItsParent() {
        let parent = makeTask("Trip", status: .someday)
        let child = makeTask("Pack") {
            $0.projects = ["Trip"]
            $0.due = today
        }
        let plan = DayScenario(tasks: [parent, child]).build(at: TestCalendar.context(TestCalendar.wednesday, "08:00"))
        #expect(plan.poolNames == ["Pack"])
        #expect(plan.pool.first?.project == "Trip")
    }

    @Test func underItsParentItNamesNone() {
        let parent = makeTask("Trip") { $0.due = today }
        let child = makeTask("Pack") {
            $0.projects = ["Trip"]
            $0.due = today
        }
        let plan = DayScenario(tasks: [parent, child]).build(at: TestCalendar.context(TestCalendar.wednesday, "08:00"))
        #expect(plan.pool.map(\.project) == [nil, nil])
        #expect(plan.pool.map(\.depth) == [0, 1])
    }

    @Test func aListNamesTheParentOnlyWhenItIsNotShown() {
        let child = makeTask("Pack") { $0.projects = ["Trip"] }
        #expect(ShownParent.parent(of: child, shown: ["Pack".noteName]) == "Trip")
        #expect(ShownParent.parent(of: child, shown: ["Pack".noteName, "Trip".noteName]) == nil)
        #expect(ShownParent.parent(of: makeTask("Trip"), shown: []) == nil)
    }

    @Test func theReviewDrawsLinesWithinAGroup() {
        let parent = DayItem(listed: makeTask("Trip"))
        var child = DayItem(listed: makeTask("Pack") { $0.projects = ["Trip"] })
        child.depth = 1
        let items = ["Trip": parent, "Pack": child]
        let guides = ReviewGroups.guides([.header(.day), .item("Trip"), .item("Pack")], items: items)
        #expect(guides["Pack"] == SubtaskGuide(depth: 1, isLast: true, passes: []))
        #expect(guides["Trip"] == nil)
    }
}
