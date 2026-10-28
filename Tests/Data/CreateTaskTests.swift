import Foundation
import Testing
@testable import SuperPooperApp

/// New tasks from the app are TaskNotes notes in the tasks folder.
@Suite("Creating tasks")
struct CreateTaskTests {
    @Test func aNewTaskIsWrittenTheTaskNotesWay() async throws {
        let sandbox = try VaultSandbox.make()
        let repository = sandbox.repository()
        let task = try await repository.create(named: "New task", status: .thisWeek)
        #expect(task.name == "New task")
        #expect(task.status == .thisWeek)
        let expected = "---\ntags:\n  - 🔫делишка\nstatus: this_week\npriority: none\n"
            + "date_created: \(sandbox.nowStamp)\ndate_modified: \(sandbox.nowStamp)\n---\n"
        expectSameBytes(try sandbox.text(of: "New task"), expected)
        #expect(try await repository.scan().tasks.contains { $0.name == "New task" && $0.status == .thisWeek })
    }

    @Test func namesAreMadeUnique() async throws {
        let sandbox = try VaultSandbox.make()
        let repository = sandbox.repository()
        _ = try await repository.create(named: "New task", status: .thisWeek)
        let second = try await repository.create(named: "New task", status: .thisWeek)
        #expect(second.name == "New task 2")
        #expect(sandbox.exists("New task 2"))
    }
}
