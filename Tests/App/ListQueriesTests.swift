import Foundation
import Testing
@testable import SuperPooperApp

/// What the screens ask the model instead of working it out themselves: the lists of the Lists tab and the pickers.
@MainActor
struct ListQueriesTests {
    private func makeModel() throws -> AppModel {
        try #require(PreviewModel.make()).model
    }

    /// The Done list reads the filed tasks when it opens; a list that does not show them leaves the folder alone.
    @Test func onlyAListOfDoneTasksReadsTheFiledOnes() async throws {
        let model = try makeModel()
        await model.perform(.done, on: "Позвонить в банк")
        let store = try #require(model.parts.services.tasks as? InMemoryTaskStore)
        _ = try await store.fileAway(makeTask("Filed in Obsidian", status: .done))
        await model.openList("someday")
        #expect(!model.filedTasks.contains { $0.name == "Filed in Obsidian" })
        await model.openList("done")
        #expect(model.filedTasks.contains { $0.name == "Filed in Obsidian" })
        #expect(model.listCount("done") == model.listContents("done", query: "").count)
        #expect(model.listContents("done", query: "банк").filed.map(\.name) == ["Позвонить в банк"])
    }

}
