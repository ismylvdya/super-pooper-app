import Foundation
import Testing
@testable import SuperPooperApp

/// Every status change of the app goes through one rule: leaving done drops the day of completion.
@MainActor
struct AppStatusChangeTests {
    private func model(withDone name: String) throws -> AppModel {
        var task = TaskNote(name: name, relativePath: "TaskNotes/Tasks/\(name).md", status: .done)
        task.completedDate = LocalDate("2026-10-20")
        return try #require(PreviewModel.make(tasks: [task])).model
    }

    @Test func archivingADoneTaskDropsItsDayOfCompletion() async throws {
        let model = try model(withDone: "Report")
        await model.perform(.archive, on: "Report")
        let archived = try #require(model.task(named: "Report"))
        #expect(archived.status == .archived)
        #expect(archived.completedDate == nil)
    }

    @Test func aDoneTaskBroughtToThisWeekIsOpenAgain() async throws {
        let model = try model(withDone: "Report")
        await model.moveToThisWeek("Report")
        let promoted = try #require(model.task(named: "Report"))
        #expect(promoted.status == .thisWeek)
        #expect(promoted.completedDate == nil)
    }

    @Test func restoringAnArchivedTaskGoesThroughTheSameRule() async throws {
        let model = try model(withDone: "Report")
        await model.perform(.restoreHalfYear, on: "Report")
        let restored = try #require(model.task(named: "Report"))
        #expect(restored.status == .halfYear)
        #expect(restored.completedDate == nil)
    }
}
