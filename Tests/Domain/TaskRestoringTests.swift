import Foundation
import Testing
@testable import SuperPooperApp

/// Undo writes back every field an action changed, from the note as it is now (.27143).
struct TaskRestoringTests {
    private let day = LocalDate("2026-10-20")

    @Test func aDoneTaskGoesBackToItsStatus() {
        let before = makeTask("Report", status: .halfYear)
        let now = before.applying([.complete(on: day)])
        let edits = TaskRestoring.edits(restoring: before, from: now)
        #expect(edits == [.status(.halfYear)])
        #expect(now.applying(edits).status == .halfYear && now.applying(edits).completedDate == nil)
    }

    @Test func aReopenedTaskIsDoneAgainOnItsDay() {
        let before = makeTask("Report").applying([.complete(on: day)])
        let now = before.applying([.reopen])
        #expect(TaskRestoring.edits(restoring: before, from: now) == [.complete(on: day)])
    }

    @Test func aHabitsMarkGoesBackDayByDay() {
        let before = makeHabit("Water") { $0.marks = [LocalDate("2026-10-19"): .done] }
        let now = before.applying([.mark(.twice, on: day), .mark(nil, on: LocalDate("2026-10-19"))])
        let edits = TaskRestoring.edits(restoring: before, from: now)
        #expect(Set(edits) == [.mark(.done, on: LocalDate("2026-10-19")), .mark(nil, on: day)])
        #expect(now.applying(edits).marks == before.marks)
    }

    @Test func linksAndFieldsGoBack() {
        let before = makeTask("Hang the shelf") {
            $0.previousTasks = ["Buy screws"]
            $0.due = TaskDue("2026-10-20T15:00")
            $0.isHighPriority = true
        }
        let now = before.applying([.removePreviousTask("Buy screws"), .addPreviousTask("Find drill"), .due(TaskDue("2026-10-21T15:00")),
                                   .highPriority(false), .showInToday(false)])
        let restored = now.applying(TaskRestoring.edits(restoring: before, from: now))
        #expect(restored == before)
    }

    @Test func anUnchangedNoteNeedsNoEdits() {
        let task = makeTask("Read")
        #expect(TaskRestoring.edits(restoring: task, from: task).isEmpty)
    }
}
