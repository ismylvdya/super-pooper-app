import Foundation
import Testing
@testable import SuperPooperApp

/// The app leaves the screen with a new note's page open: what was set there is made the note at once, and the page
/// becomes the note's own, so nothing typed is lost if the system closes the app.
@MainActor
struct KeepDraftTests {
    private func makeModel() throws -> AppModel {
        try #require(PreviewModel.make()).model
    }

    @Test func aTypedDraftBecomesTheNote() async throws {
        let model = try makeModel()
        var page = model.newItemPage(kind: .task)
        page.name = "Long thought"
        page.draft.body = "A lot written here"
        let name = await model.keepNewItem(page, unnamed: "Unnamed")
        #expect(name == "Long thought")
        #expect(model.task(named: "Long thought") != nil)
    }

    @Test func aTextWithoutANameIsKeptUnnamed() async throws {
        let model = try makeModel()
        var page = model.newItemPage(kind: .task)
        page.draft.body = "Only the text"
        #expect(await model.keepNewItem(page, unnamed: "Unnamed") == "Unnamed")
    }

    @Test func anUntouchedPageKeepsNothing() async throws {
        let model = try makeModel()
        #expect(await model.keepNewItem(model.newItemPage(kind: .task), unnamed: "Unnamed") == nil)
    }

    @Test func theNewNotesPageBecomesTheNotesOwn() {
        let router = Router()
        let seed = NewItemSeed(kind: .task)
        router.paths[.today] = [.lists, .newItem(seed)]
        router.replace(.newItem(seed), with: .task("Long thought"), on: .today)
        #expect(router.paths[.today] == [.lists, .task("Long thought")])
    }
}
