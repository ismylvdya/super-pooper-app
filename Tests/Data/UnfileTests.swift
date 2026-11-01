import Foundation
import Testing
@testable import SuperPooperApp

/// Return from the Done list in the TaskNotes adapter: the note moves back from the done folder into the tasks folder
/// and is reopened the TaskNotes way — `status: this_week`, no `completed_date` — with nothing else changed.
@Suite("Unfile")
struct UnfileTests {
    private let name = "Старая сделанная задача"

    @Test func aFiledTaskComesBackIntoTheTasksFolderReopened() async throws {
        let note = try await SandboxNote(name)
        let original = try note.text()
        let filed = try await note.repository.fileAway(note.task)
        let doneFile = note.sandbox.vault.appendingPathComponent("TaskNotes/Done/\(name).md")
        #expect(filed.id.relativePath == "TaskNotes/Done/\(name).md")

        let back = try await note.repository.unfile(filed)

        #expect(back.name == name && back.id.relativePath == "TaskNotes/Tasks/\(name).md")
        #expect(back.status == .thisWeek && back.completedDate == nil)
        #expect(!FileManager.default.fileExists(atPath: doneFile.path))
        let completed = try #require(original.components(separatedBy: "\n").first { $0.hasPrefix("completed_date: ") })
        let modified = try #require(original.components(separatedBy: "\n").first { $0.hasPrefix("date_modified: ") })
        expectSameBytes(try note.sandbox.text(of: name), try original
            .replacingOnce("status: done\n", with: "status: this_week\n")
            .replacingOnce(completed + "\n", with: "")
            .replacingOnce(modified, with: "date_modified: \(note.sandbox.nowStamp)"))
        #expect(try await note.repository.load().tasks.contains { $0.name == name })
        #expect(try await note.repository.filedTasks().isEmpty)
    }

    /// A new task took the name meanwhile: the returned one gets a number, the new one stays as it is.
    @Test func aTakenNameGetsANumber() async throws {
        let note = try await SandboxNote(name)
        let filed = try await note.repository.fileAway(note.task)
        _ = try await note.repository.create(.newTask, named: name)
        let newText = try note.sandbox.text(of: name)

        let back = try await note.repository.unfile(filed)

        #expect(back.name == "\(name) 2" && back.status == .thisWeek)
        #expect(try note.sandbox.text(of: name) == newText)
    }
}
