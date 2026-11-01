import Foundation
import Testing
@testable import SuperPooperApp

/// The tasks as the store gave them and the app changed them: a scan that ran while the app wrote keeps what was
/// written meanwhile.
@MainActor
struct TaskStateTests {
    private func scan(_ tasks: [TaskItem]) -> VaultScanResult {
        VaultScanResult(tasks: tasks, fileProblems: [], conflicted: [])
    }

    @Test func aNoteWrittenDuringAScanKeepsWhatWasWritten() {
        let state = TaskState()
        let note = makeTask("Report")
        state.setScanResult(scan([note]))
        state.beginTrackingWrites()
        state.written(makeTask("Report") { $0.isHighPriority = true })
        state.setScanResult(scan([note]))
        state.endTrackingWrites()
        #expect(state.task(named: "Report")?.isHighPriority == true)
    }

    /// The scan had listed the files before the note was created, and before the other one was trashed.
    @Test func notesCreatedOrRemovedDuringAScanStaySo() {
        let state = TaskState()
        let gone = makeTask("Gone")
        state.setScanResult(scan([gone]))
        state.beginTrackingWrites()
        state.written(makeTask("New"))
        state.remove(gone)
        state.setScanResult(scan([gone]))
        state.endTrackingWrites()
        #expect(state.tasks.map(\.name) == ["New"])
    }

    /// Outside a sync a scan is the truth.
    @Test func withoutASyncTheScanWins() {
        let state = TaskState()
        state.written(makeTask("Report") { $0.isHighPriority = true })
        state.setScanResult(scan([makeTask("Report")]))
        #expect(state.task(named: "Report")?.isHighPriority == false)
        #expect(state.vaultState == .ready)
    }

    @Test func aVaultThatCannotBeReadShowsNoTasks() {
        let state = TaskState()
        state.setScanResult(VaultScanResult(tasks: [makeTask("Report")], fileProblems: [.notDownloaded(file: "A.md")], conflicted: []))
        state.setVaultState(.failed(.vaultAccessDenied))
        #expect(state.tasks.isEmpty && state.fileProblems.isEmpty)
    }

    @Test func subtasksAreFoundByTheParentsNameInAnyCase() {
        let state = TaskState()
        state.setScanResult(scan([makeTask("Parent"), makeTask("Child") { $0.projects = ["parent"] }]))
        #expect(state.subtasks(of: "Parent").map(\.name) == ["Child"])
    }
}
