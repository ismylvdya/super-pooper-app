import Foundation
import Testing
@testable import SuperPooperApp

/// Return in the name of the new task page saves the note at once, with everything set on the page so far (.1571).
@MainActor
struct SaveOnReturnTests {
    @Test func returnCreatesTheNoteWithItsDraftAndSaysSo() async throws {
        let events = RecordingEvents()
        let model = try #require(PreviewModel.make(appEvents: events)).model
        var page = model.newItemPage(kind: .task)
        page.draft.apply([.highPriority(true)])
        page.name = "Купить хлеб"

        let saved = await model.createOnReturn(from: page)

        #expect(saved == "Купить хлеб")
        #expect(model.task(named: "Купить хлеб")?.isHighPriority == true)
        #expect(events.sent.last == .created("Купить хлеб"))
    }

    @Test func anEmptyOrForbiddenNameSavesNothing() async throws {
        let events = RecordingEvents()
        let model = try #require(PreviewModel.make(appEvents: events)).model
        var page = model.newItemPage(kind: .task)
        #expect(await model.createOnReturn(from: page) == nil)
        page.name = "Встреча: Анна"
        #expect(await model.createOnReturn(from: page) == nil)
        #expect(model.task(named: "Встреча: Анна") == nil)
        #expect(!events.sent.contains { if case .created = $0 { true } else { false } })
    }
}
