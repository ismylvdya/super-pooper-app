import Foundation
import Testing
@testable import SuperPooperApp

/// The app state reports what happened as events, never as text; what the screens used to announce themselves comes
/// from the intent that did it.
@MainActor
struct AppEventTests {
    private let events = RecordingEvents()

    private func makeModel() throws -> AppModel {
        try #require(PreviewModel.make(appEvents: events)).model
    }

    @Test func aRenameReportsTheNewName() async throws {
        let model = try makeModel()
        #expect(await model.rename("Сдать отчёт", to: " Отчёт "))
        #expect(events.sent == [.renamed("Отчёт")])
    }

    /// Leaving the new task page with a name a note cannot take creates nothing and says why.
    @Test func aNewNoteWithANameItCannotTakeIsRejected() async throws {
        let model = try makeModel()
        var page = model.newItemPage(kind: .task)
        page.name = "Meet: Anna"
        #expect(await model.create(from: page, unnamed: "Unnamed") == false)
        #expect(events.sent == [.nameRejected(.forbidden(":"), name: "Meet: Anna")])
        #expect(model.task(named: "Meet: Anna") == nil)
    }

    @Test func aNewNoteIsReportedCreated() async throws {
        let model = try makeModel()
        var page = model.newItemPage(kind: .task)
        page.name = "Meet Anna"
        #expect(await model.create(from: page, unnamed: "Unnamed"))
        #expect(events.sent == [.created("Meet Anna")])
    }

    @Test func anUntouchedNewItemPageCreatesNothingAndSaysNothing() async throws {
        let model = try makeModel()
        #expect(await model.create(from: model.newItemPage(kind: .task), unnamed: "Unnamed") == false)
        #expect(events.sent.isEmpty)
    }

    @Test func resettingTheOrderIsReported() throws {
        let model = try makeModel()
        model.setManualOrder(["Сдать отчёт"])
        model.resetOrder()
        #expect(events.sent == [.orderReset])
    }

    /// Errors reach the frontend as facts: the store's and the vault's by kind, any other by domain and code.
    @Test func errorsBecomeFailuresWithTheirFacts() {
        #expect(AppFailure(TaskStoreError.nameTaken("A")) == .nameTaken("A"))
        #expect(AppFailure(TaskStoreError.fileMissing("A")) == .noteMissing("A"))
        #expect(AppFailure(VaultAccessError.accessDenied) == .vaultAccessDenied)
        #expect(AppFailure(CalendarEditError.eventNotFound) == .eventNotFound)
        #expect(AppFailure(CocoaError(.fileReadNoPermission)) == .system(domain: NSCocoaErrorDomain, code: 257))
    }
}
