import Testing
@testable import SuperPooperApp

/// A field written here that was changed elsewhere too is reported by its domain name; list deltas merge silently.
@Suite("Task conflicts")
struct TaskConflictsTests {
    @Test func onlySingleValueFieldsChangedOnBothSidesClash() {
        let seen = makeTask("Report")
        var latest = seen
        latest.due = TaskDue("2026-10-23")
        latest.projects = ["Draft"]
        latest.timeEstimate = 60
        let edits: [TaskEdit] = [.due(TaskDue("2026-10-24")), .addProject("Outline"), .reopen, .highPriority(true)]
        #expect(TaskConflicts.fields(edits, seen: seen, latest: latest) == [.due])
    }


    @Test func completingAndReopeningClashWithAStatusChangedElsewhere() {
        let seen = makeTask("Report")
        var latest = seen
        latest.status = .someday
        #expect(TaskConflicts.fields([.complete(on: LocalDate("2026-10-21"))], seen: seen, latest: latest) == [.status])
    }
}
