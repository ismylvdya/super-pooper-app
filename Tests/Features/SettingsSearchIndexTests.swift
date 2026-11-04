import Testing
@testable import SuperPooperApp

/// The search in Settings finds a section by a row's title (showing only the rows that match) or by its own title
/// (showing all of them), and every title it knows is a real text of the app.
struct SettingsSearchIndexTests {
    private func localize(_ key: String) -> String {
        ["settings.timeline": "Timeline", "settings.timeline.bellSize": "Bell size", "settings.timeline.taskFont": "Task font",
         "settings.clock": "Clock", "settings.clock.zone": "Time zone"][key] ?? ""
    }

    @Test func aRowsTitleFindsItsSectionWithOnlyThatRow() {
        let results = SettingsSearchIndex.results("bell", localize: localize)
        #expect(results.map(\.title) == ["Timeline"])
        #expect(results.first?.rows == ["Bell size"])
        #expect(results.first?.route == .taskSettings)
    }

    @Test func aSectionsTitleShowsAllItsRows() {
        let results = SettingsSearchIndex.results("clock", localize: localize)
        #expect(results.first?.title == "Clock")
        #expect(results.first?.rows.contains("Time zone") == true)
        #expect(results.first?.route == .clockSettings, "the Timezone widget has its own page")
    }

    @Test func anEmptyQueryFindsNothing() {
        #expect(SettingsSearchIndex.results("  ", localize: localize).isEmpty)
    }

    @Test func everyTitleIsLocalized() {
        for section in SettingsSearchIndex.sections {
            for key in [section.title] + section.rows { #expect(L10n.string(key) != key, "\(key)") }
        }
    }
}
