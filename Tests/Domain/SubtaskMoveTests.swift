import Testing
@testable import SuperPooperApp

/// A task dragged over the right part of a list becomes the subtask of the row above it.
struct SubtaskMoveTests {
    @Test func itTakesTheParentsListAndPool() throws {
        let parent = makeTask("Trip", status: .halfYear, inPool: false)
        let task = makeTask("Pack")
        let edits = try #require(SubtaskMove.changes(moving: task, under: parent, index: 0, in: [parent, task]))
        #expect(edits == [.parent("Trip"), .subtaskOrder(0), .status(.halfYear), .inTodayPool(false)])
        #expect(task.applying(edits).projects == ["Trip"])
    }

    @Test func notUnderItselfNorUnderItsOwnSubtask() {
        let task = makeTask("Trip")
        let child = makeTask("Pack") { $0.projects = ["Trip"] }
        let grandchild = makeTask("Socks") { $0.projects = ["Pack"] }
        let all = [task, child, grandchild]
        #expect(SubtaskMove.changes(moving: task, under: task, index: nil, in: all) == nil)
        #expect(SubtaskMove.changes(moving: task, under: grandchild, index: nil, in: all) == nil)
        #expect(SubtaskMove.changes(moving: grandchild, under: task, index: 1, in: all) == [.parent("Trip"), .subtaskOrder(1)])
    }

    /// Moved under another parent, a subtask leaves the one it had.
    @Test func aNewParentReplacesTheOld() {
        let old = makeTask("Old")
        let child = makeTask("Pack") { $0.projects = ["Old"] }
        #expect(child.applying([.parent("New")]).projects == ["New"])
        #expect(child.applying([.parent(nil)]).projects.isEmpty)
        _ = old
    }
}
