import Foundation
import Testing
@testable import SuperPooperApp

/// Done tasks of earlier days move to the done folder; today's, habits and open tasks stay.
struct DoneFilingTests {
    private let today = LocalDate("2026-10-21")

    @Test func onlyTasksDoneBeforeTodayAreFiled() {
        let yesterday = makeTask("Yesterday", status: .done) { $0.completedDate = LocalDate("2026-10-20") }
        let undated = makeTask("Undated", status: .done)
        let doneToday = makeTask("Today", status: .done) { $0.completedDate = LocalDate("2026-10-21") }
        let open = makeTask("Open")
        let habit = makeTask("Habit", status: .habit)
        #expect(DoneFiling.due([yesterday, undated, doneToday, open, habit], today: today).map(\.name) == ["Yesterday", "Undated"])
    }

    @Test func tasksWaitingForAFiledOneLoseThatLink() {
        let waiting = makeTask("Hang the shelf") { $0.previousTasks = ["buy screws"] }
        let other = makeTask("Other")
        #expect(DoneFiling.unlinking("Buy screws", from: [waiting, other]).map(\.name) == ["Hang the shelf"])
    }

    /// The note moves next to the tasks folder; a name taken there gets a number.
    @Test func theNoteMovesToTheDoneFolder() async throws {
        let first = try await SandboxNote("Купить молоко")
        try await first.repository.fileAway(first.task)
        let done = first.sandbox.vault.appendingPathComponent("TaskNotes/Done")
        #expect(FileManager.default.fileExists(atPath: done.appendingPathComponent("Купить молоко.md").path))
        #expect(try await first.repository.scan().tasks.contains { $0.name == "Купить молоко" } == false)
    }
}
