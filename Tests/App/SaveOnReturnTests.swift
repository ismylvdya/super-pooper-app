import Foundation
import Testing
@testable import SuperPooperApp

/// Return in the name of the new task page and Back create the note the same way, with everything set on the page and a banner.
@MainActor
struct SaveOnReturnTests {
    @Test func returnCreatesTheNoteWithItsDraftAndSaysSo() async throws {
        let events = RecordingEvents()
        let model = try #require(PreviewModel.make(appEvents: events)).model
        var page = model.newItemPage(kind: .task)
        page.draft.apply([.highPriority(true)])
        page.name = "Купить хлеб"

        #expect(await model.create(from: page, unnamed: "Unnamed"))

        #expect(model.task(named: "Купить хлеб")?.isHighPriority == true)
        #expect(events.sent.last == .created("Купить хлеб"))
    }

    @Test func anEmptyOrForbiddenNameSavesNothing() async throws {
        let events = RecordingEvents()
        let model = try #require(PreviewModel.make(appEvents: events)).model
        var page = model.newItemPage(kind: .task)
        #expect(await model.create(from: page, unnamed: "Unnamed") == false)
        page.name = "Встреча: Анна"
        #expect(await model.create(from: page, unnamed: "Unnamed") == false)
        #expect(model.task(named: "Встреча: Анна") == nil)
        #expect(!events.sent.contains { if case .created = $0 { true } else { false } })
    }
}
