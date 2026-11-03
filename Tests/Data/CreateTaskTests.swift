import Foundation
import Testing
@testable import SuperPooperApp

/// New tasks from the app are TaskNotes notes in the tasks folder.
@Suite("Creating tasks")
struct CreateTaskTests {
    @Test func aNewTaskIsWrittenTheTaskNotesWay() async throws {
        let sandbox = try VaultSandbox.make()
        let repository = sandbox.repository()
        let task = try await repository.create(NoteDraft(status: .thisWeek), named: "New task")
        #expect(task.name == "New task")
        #expect(task.status == .thisWeek)
        let expected = "---\ntags:\n  - 🔫делишка\nstatus: this_week\npriority: none\n"
            + "date_created: \(sandbox.nowStamp)\ndate_modified: \(sandbox.nowStamp)\n---\n"
        expectSameBytes(try sandbox.text(of: "New task"), expected)
        #expect(try await repository.load().tasks.contains { $0.name == "New task" && $0.status == .thisWeek })
    }

    @Test func namesAreMadeUnique() async throws {
        let sandbox = try VaultSandbox.make()
        let repository = sandbox.repository()
        _ = try await repository.create(NoteDraft(status: .thisWeek), named: "New task")
        let second = try await repository.create(NoteDraft(status: .thisWeek), named: "New task")
        #expect(second.name == "New task 2")
        #expect(sandbox.exists("New task 2"))
    }

    /// A habit's subtask is a TaskNotes recurring task: the habit status, the parent's rule, a link to the parent in
    /// `projects`, and "repeatable" among the app's settings of the note.
    @Test func aRepeatableSubtaskIsWrittenAsTaskNotesWrites() async throws {
        let sandbox = try VaultSandbox.make()
        let repository = sandbox.repository()
        let rule = try RecurrenceCodec.parse("DTSTART:20260901;FREQ=WEEKLY;BYDAY=MO,WE,FR").get()
        let parent = try await repository.create(NoteDraft(status: .habit, changes: [.recurrence(rule)]), named: "Зарядка")
        let subtask = try await repository.create(.subtask(of: parent), named: "Отжимания")
        let lines = try sandbox.text(of: "Отжимания").split(separator: "\n").map(String.init)
        #expect(lines.contains("status: habit"))
        #expect(lines.contains("recurrence: DTSTART:20260901;FREQ=WEEKLY;BYDAY=MO,WE,FR"))
        #expect(lines.contains("projects:") && lines.contains("  - \"[[Зарядка]]\""))
        let settings = try #require(lines.first { $0.hasPrefix("fromSuperPooperApp: '{") })
        #expect(settings.contains("\"repeatable\":true"))
        let read = try #require(try await repository.load().tasks.first { $0.name == "Отжимания" })
        #expect(read.isHabit && read.habit.repeatable && read.recurrence == rule && read.projects == ["Зарядка"])
        #expect(subtask.recurrence == rule)
    }
}
