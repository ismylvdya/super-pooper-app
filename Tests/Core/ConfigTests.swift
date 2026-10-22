import Foundation
import Testing
@testable import SuperPooper

/// The bundled configs load and are complete; config typos produce readable errors.
struct ConfigTests {
    @Test func bundledConfigsLoad() throws {
        let config = try AppConfig.load(bundle: Bundle(for: BundleToken.self).appHostBundle)
        #expect(config.todayLayout.blocks.map(\.block) == ["pool", "timeline"])
        #expect(config.sort.pool == PoolSortCriterion.allCases)
        #expect(config.rules.timeEstimates.map(\.minutes) == [2, 15, 60, 240])
        #expect(config.fieldMapping.fields.previousTasks == "previous_task")
    }

    @Test func everyConfigTextHasACatalogEntry() throws {
        let bundle = Bundle(for: BundleToken.self).appHostBundle
        let config = try AppConfig.load(bundle: bundle)
        var keys = config.actions.actions.flatMap { [$0.title, $0.confirmTitle, $0.confirmMessage].compactMap { $0 } }
        keys += config.rules.timeEstimates.map(\.label)
        for key in keys {
            #expect(bundle.localizedString(forKey: key, value: "∅", table: nil) != "∅", "missing text for \(key)")
        }
    }

    @Test func layoutTypoIsReported() {
        let json = Data(#"{"axis": "diagonal", "spacing": "blockGap", "blocks": []}"#.utf8)
        #expect(throws: ConfigError.self) { try ConfigLoader.decode(ScreenLayout.self, from: json, file: "today.layout.json") }
        do {
            _ = try ConfigLoader.decode(ScreenLayout.self, from: json, file: "today.layout.json")
        } catch let error as ConfigError {
            #expect(error.description.contains("today.layout.json"))
            #expect(error.description.contains("axis"))
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test func unknownTokenKeyIsReported() {
        let json = Data(#"{"groupGapp": 18}"#.utf8)
        do {
            _ = try ConfigLoader.decode(TokenTable<SpacingToken, Double>.self, from: json, file: "tokens.json")
            Issue.record("expected an error")
        } catch let error as ConfigError {
            #expect(error.description.contains("groupGapp"))
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test func missingActionDefinitionIsReported() throws {
        let registry = ActionRegistry(actions: [], menus: [:])
        #expect(throws: ConfigError.self) { try registry.validate(file: "actions.json") }
    }

    @Test func storedSettingsGetDefaultsForNewFields() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = JSONFileStore(directory: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = try AppConfig.load(bundle: Bundle(for: BundleToken.self).appHostBundle)
        try store.writeData(Data(#"{"pool": {"visibleCount": 5}}"#.utf8), to: SettingsStore.fileName)
        let settings = SettingsStore(store: store, defaults: config.defaultSettings).load()
        #expect(settings.pool.visibleCount == 5)
        #expect(settings.vault.tasksFolder == "TaskNotes/Tasks")
        #expect(settings.day.boundary == LocalTime(hour: 4, minute: 0))
    }
}

private final class BundleToken {}

private extension Bundle {
    /// Unit tests run inside the app, whose bundle holds the configs.
    var appHostBundle: Bundle { .main }
}
