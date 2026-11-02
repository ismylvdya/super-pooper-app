import Foundation
import Testing
@testable import SuperPooperApp

/// A menu's frequent actions come first and the rarer ones (`actions.json` → `more`) are marked to stand under a divider.
@MainActor
struct MenuEntriesTests {
    @Test func theRarerActionsComeLastAndAreMarked() throws {
        let model = try #require(PreviewModel.make()).model
        let entries = model.menuEntries(.habitNotification, for: nil)
        #expect(entries.map(\.action.id) == [.done, .skipToday, .snooze])
        #expect(entries.map(\.isMore) == [false, false, true])
    }

    @Test func aMenuWithoutMoreDecodesAllActionsAsFrequent() throws {
        let definition = try JSONDecoder().decode(MenuDefinition.self, from: Data(#"{"actions": ["done", "delete"]}"#.utf8))
        #expect(definition.frequent == [.done, .delete])
        #expect(definition.more.isEmpty)
        let split = try JSONDecoder().decode(MenuDefinition.self, from: Data(#"{"actions": ["done"], "more": ["snooze"]}"#.utf8))
        #expect(split.actions == [.done, .snooze])
    }
}
