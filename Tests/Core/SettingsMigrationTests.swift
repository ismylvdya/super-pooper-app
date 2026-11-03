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

    /// The day routine is gone: its order in an older settings file is read past and not written back.
    @Test func theDayRoutineIsDroppedWhenRead() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = JSONFileStore(directory: directory)
        let config = try AppConfig.load()
        try store.writeData(Data(#"{"habits": {"morningRoutine": ["Душ"], "dayRoutine": ["Обед"], "eveningRoutine": ["Чтение"]}}"#.utf8),
                            to: SettingsStore.fileName)
        let settings = SettingsStore(store: store, defaults: config.defaultSettings)
        let loaded = settings.load()
        #expect(loaded.habits.morningRoutine == ["Душ"] && loaded.habits.eveningRoutine == ["Чтение"])
        try settings.save(loaded)
        let written = try #require(store.readData(SettingsStore.fileName))
        #expect(!String(decoding: written, as: UTF8.self).contains("dayRoutine"))
    }

    /// The sort rules of the routines by part of the day are gone; a user's own order of the rules keeps the rest.
    @Test func retiredSortRulesLeaveTheVaultSettings() {
        let note = Data(#"{"pool": {"criteria": ["morningRoutine", "highPriority", "habitTimeOfDay", "shortFirst"]}}"#.utf8)
        #expect(SyncedSettings.merged(note: note, over: TestConfig.defaults).pool.criteria == ["highPriority", "shortFirst"])
    }

    /// With the old accent gone from the settings, the tokens take an accent override like any other color.
    @Test func theTokensApplyEveryKnownColor() {
        let tokens = TestConfig.tokens.overridingColors(["accent": "#FF0000", "unknown": "#00FF00", "task": "nothex"])
        #expect(tokens.uiColor(.accent).hexString == "#FF0000")
        #expect(tokens.uiColor(.task).hexString == TestConfig.tokens.uiColor(.task).hexString)
    }
}
