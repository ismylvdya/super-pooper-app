import Foundation
import Testing
@testable import SuperPooperApp

/// Colors older versions let the user pick (the accent, Twice, missed days) are dropped as the settings are read, from
/// this device's file and from the vault's settings, so the tokens apply every override they get.
struct SettingsMigrationTests {
    @Test func retiredColorsLeaveTheSettingsFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = JSONFileStore(directory: directory)
        let config = try AppConfig.load()
        try store.writeData(Data(##"{"colors": {"accent": "#FF0000", "twice": "#00FF00", "task": "#111111"}}"##.utf8),
                            to: SettingsStore.fileName)
        #expect(SettingsStore(store: store, defaults: config.defaultSettings).load().colors == ["task": "#111111"])
    }

    @Test func retiredColorsLeaveTheVaultSettings() {
        let note = Data(##"{"colors": {"accent": "#FF0000", "missed": "#00FF00", "habit": "#222222"}}"##.utf8)
        #expect(SyncedSettings.merged(note: note, over: TestConfig.defaults).colors == ["habit": "#222222"])
    }

    /// With the old accent gone from the settings, the tokens take an accent override like any other color.
    @Test func theTokensApplyEveryKnownColor() {
        let tokens = TestConfig.tokens.overridingColors(["accent": "#FF0000", "unknown": "#00FF00", "task": "nothex"])
        #expect(tokens.uiColor(.accent).hexString == "#FF0000")
        #expect(tokens.uiColor(.task).hexString == TestConfig.tokens.uiColor(.task).hexString)
    }
}
