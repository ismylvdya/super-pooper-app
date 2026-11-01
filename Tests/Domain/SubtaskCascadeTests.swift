import Foundation
import Testing
@testable import SuperPooperApp

/// Deleting or completing a parent takes its subtasks along, all the way down (.1965), except a subtask that also
/// belongs to another parent that stays open.
struct SubtaskCascadeTests {
    private func subtask(_ name: String, of parents: String..., status: TaskStatus = .thisWeek) -> TaskItem {
        makeTask(name, status: status) { $0.projects = parents }
    }

    private func going(with parent: String, in tasks: [TaskItem], _ change: SubtaskCascade.Change) throws -> [String] {
        let root = try #require(tasks.first { $0.name == parent })
        return SubtaskCascade.subtasks(of: root, in: tasks, change: change).map(\.name)
    }

    @Test(arguments: [SubtaskCascade.Change.deletion, .completion])
    func subtasksGoAlongAllTheWayDown(change: SubtaskCascade.Change) throws {
        let tasks = [makeTask("Renovation"), subtask("Paint", of: "Renovation"), subtask("Buy paint", of: "Paint"),
                     subtask("Pick a color", of: "Buy paint"), makeTask("Unrelated")]
        #expect(try going(with: "Renovation", in: tasks, change) == ["Paint", "Buy paint", "Pick a color"])
        #expect(try going(with: "Paint", in: tasks, change) == ["Buy paint", "Pick a color"])
        #expect(try going(with: "Unrelated", in: tasks, change).isEmpty)
    }

    /// A subtask of two parents stays while the other one stays open, and goes when that one goes along too.
    @Test(arguments: [SubtaskCascade.Change.deletion, .completion])
    func aSubtaskOfAnotherOpenParentStays(change: SubtaskCascade.Change) throws {
        let tasks = [makeTask("Move"), makeTask("Renovation"), subtask("Pack books", of: "Move"),
                     subtask("Buy boxes", of: "Move", "Renovation"), subtask("Tape", of: "Buy boxes")]
        #expect(try going(with: "Move", in: tasks, change) == ["Pack books"])
        let underLife = [makeTask("Life"), subtask("Move", of: "Life"), subtask("Renovation", of: "Life"),
                         subtask("Pack books", of: "Move"), subtask("Buy boxes", of: "Move", "Renovation"), subtask("Tape", of: "Buy boxes")]
        #expect(try going(with: "Life", in: underLife, change) == ["Move", "Renovation", "Pack books", "Buy boxes", "Tape"])
    }

    /// A parent that is done, archived or missing keeps nothing.
    @Test func anotherParentThatIsNotOpenKeepsNothing() throws {
        for other in [makeTask("Old", status: .done), makeTask("Old", status: .archived)] {
            let tasks = [makeTask("Move"), other, subtask("Buy boxes", of: "Move", "Old")]
            #expect(try going(with: "Move", in: tasks, .deletion) == ["Buy boxes"])
        }
        let orphanLink = [makeTask("Move"), subtask("Buy boxes", of: "Move", "Gone")]
        #expect(try going(with: "Move", in: orphanLink, .deletion) == ["Buy boxes"])
    }

    /// A completion skips what needs no writing (done subtasks, habits) but reaches down through them.
    @Test func aCompletionWritesOnlyOpenTasks() throws {
        let tasks = [makeTask("Trip"), subtask("Book", of: "Trip", status: .done), subtask("Pay", of: "Book"),
                     makeHabit("Stretch on the plane") { $0.projects = ["Trip"] }]
        #expect(try going(with: "Trip", in: tasks, .completion) == ["Pay"])
        #expect(try going(with: "Trip", in: tasks, .deletion) == ["Book", "Pay", "Stretch on the plane"])
    }

    /// Names match as Obsidian links do, whatever the case; a note that names itself as its parent does not keep itself,
    /// and a loop of parents ends.
    @Test func linksIgnoreCaseAndLoopsEnd() throws {
        let tasks = [makeTask("Trip"), subtask("Pack", of: "trip"), subtask("Bag", of: "Pack", "Bag")]
        #expect(try going(with: "Trip", in: tasks, .deletion) == ["Pack", "Bag"])
        let loop = [subtask("A", of: "B"), subtask("B", of: "A")]
        #expect(try going(with: "A", in: loop, .deletion) == ["B"])
    }

    @Test func onlyDeleteAndDoneTakeSubtasksAlong() {
        #expect(ActionID.allCases.filter { $0.subtaskChange != nil } == [.done, .delete])
    }
}
