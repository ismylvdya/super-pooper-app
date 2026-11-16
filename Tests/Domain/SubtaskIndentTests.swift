import Testing
@testable import SuperPooperApp

/// One tab right or left from the swipe to the right.
struct SubtaskIndentTests {
    private let trip = makeTask("Trip")
    private let pack = makeTask("Pack") { $0.projects = ["Trip"]; $0.subtaskOrder = 0 }
    private let socks = makeTask("Socks") { $0.projects = ["Pack"]; $0.subtaskOrder = 0 }
    private let call = makeTask("Call")

    private func rows(_ items: [(TaskItem, Int)]) -> [DayItem] {
        items.map { task, depth in
            var item = DayItem(listed: task)
            item.depth = depth
            return item
        }
    }

    /// Under a task of the top level, it is its subtask; under a subtask, it stands beside it under the same parent.
    @Test func rightIsOneTab() {
        let all = [trip, pack, call]
        #expect(SubtaskIndent.indent("Call", rows: rows([(trip, 0), (call, 0)]), tasks: all)?.first == .parent("Trip"))
        let edits = SubtaskIndent.indent("Call", rows: rows([(trip, 0), (pack, 1), (call, 0)]), tasks: all)
        #expect(edits?.prefix(2) == [.parent("Trip"), .subtaskOrder(1)])
        #expect(SubtaskIndent.indent("Trip", rows: rows([(trip, 0), (call, 0)]), tasks: all) == nil, "the first row has nothing above")
        #expect(SubtaskIndent.indent("Pack", rows: rows([(trip, 0), (pack, 1)]), tasks: all) == nil, "a subtask goes left, not right")
    }

    /// Left is one level up, right after the old parent; from the first level, a task of its own.
    @Test func leftIsOneLevelUp() {
        let all = [trip, pack, socks, call]
        #expect(SubtaskIndent.outdent("Socks", tasks: all)?.edits == [.parent("Trip"), .subtaskOrder(1)])
        #expect(SubtaskIndent.outdent("Pack", tasks: all)?.edits == [.parent(nil), .subtaskOrder(nil)])
        #expect(SubtaskIndent.outdent("Call", tasks: all) == nil)
    }

    @Test func outOfItsParentItStandsRightAfterIt() {
        var a = makeTask("A"); a.storeOrder = 1
        var b = makeTask("B"); b.storeOrder = 3
        var child = makeTask("Child") { $0.projects = ["A"] }; child.storeOrder = 2
        #expect(SubtaskIndent.order(placing: "Child", after: "A", among: [a, b, child]) == ["A", "Child", "B"])
    }
}
