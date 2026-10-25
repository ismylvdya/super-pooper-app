import Foundation
import Testing
@testable import SuperPooper

/// The ```SuperPooperApp block in note bodies and the settings note in the vault.
@Suite("App block and settings note")
struct AppBlockTests {
    private let block = "```SuperPooperApp\n{\"a\":1}\n```\n"

    @Test func theBlockIsHiddenFromTheDescription() {
        let split = AppBlock.split(block + "\nМоё описание\n")
        #expect(split.block == block + "\n")
        #expect(split.visible == "Моё описание\n")
        #expect(AppBlock.split("Просто текст").block.isEmpty)
    }

    @Test func editingTheDescriptionKeepsTheBlockFirst() {
        let split = AppBlock.split(block + "\nСтарое\n")
        #expect(AppBlock.join(block: split.block, visible: "Новое\n") == block + "\nНовое\n")
        #expect(AppBlock.join(block: "", visible: "Без блока") == "Без блока")
    }

    @Test func theJSONIsRead() {
        #expect(AppBlock.json(in: block + "text") == Data("{\"a\":1}".utf8))
        #expect(AppBlock.json(in: "```swift\nx\n```\n") == nil)
    }

    @Test func aDescriptionEditDoesNotTouchTheBlock() async throws {
        let note = try await SandboxNote("Купить молоко")
        let withBlock = try note.text().replacingOccurrences(of: "\n---\n", with: "\n---\n" + block, options: [], range: nil)
        try note.sandbox.write(withBlock, to: note.task.name)
        let reloaded = try await SandboxNote("Купить молоко", sandbox: note.sandbox)
        #expect(!(try await reloaded.repository.body(of: reloaded.task)).contains("SuperPooperApp"))
        _ = try await reloaded.repository.setBody("Новый текст\n", of: reloaded.task)
        let text = try reloaded.text()
        #expect(text.contains(block) && text.hasSuffix("Новый текст\n"))
    }

    @Test func settingsFromTheNoteOverwriteOnlyWhatTheyContain() throws {
        var settings = TestConfig.defaults
        settings.sources.anchorCalendarIDs = ["here"]
        let json = Data(#"{"appearance":{"pastOpacity":0.5},"habits":{"morningRoutine":["Душ"]}}"#.utf8)
        let merged = SyncedSettings.merged(note: json, over: settings)
        #expect(merged.appearance.pastOpacity == 0.5 && merged.habits.morningRoutine == ["Душ"])
        #expect(merged.sources.anchorCalendarIDs == ["here"] && merged.timeline == settings.timeline)
        #expect(SyncedSettings.merged(note: Data("not json".utf8), over: settings) == settings)
    }

    @Test func theSettingsNoteKeepsEverySettingAsAProperty() async throws {
        let sandbox = try VaultSandbox.make()
        let note = settingsNote(in: sandbox)
        #expect(await note.read() == nil)
        var settings = TestConfig.defaults
        settings.timeline.hoursBefore = 5
        settings.clock.prefix = "12"
        settings.habits.morningRoutine = ["Душ", "Завтрак"]
        try await note.write(try JSONEncoder.store.encode(SyncedSettings(settings)))

        let back = try #require(await note.read())
        #expect(SyncedSettings.merged(note: back, over: TestConfig.defaults) == settings)
        let text = try String(contentsOf: noteURL(in: sandbox), encoding: .utf8)
        #expect(text.hasPrefix("---\n"))
        #expect(text.contains("timeline.hoursBefore: 5\n") && text.contains("clock.prefix: \"12\"\n"))
        #expect(!text.contains("```"))
    }

    @Test func anOldBlockIsReadAndReplacedByProperties() async throws {
        let sandbox = try VaultSandbox.make()
        let url = noteURL(in: sandbox)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try ("```SuperPooperApp\n{\"appearance\":{\"pastOpacity\":0.5}}\n```\n\nМои заметки\n").write(to: url, atomically: true, encoding: .utf8)
        let note = settingsNote(in: sandbox)

        let old = try #require(await note.read())
        #expect(SyncedSettings.merged(note: old, over: TestConfig.defaults).appearance.pastOpacity == 0.5)
        try await note.write(try JSONEncoder.store.encode(SyncedSettings(TestConfig.defaults)))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(!text.contains("SuperPooperApp") && text.contains("appearance.pastOpacity: ") && text.hasSuffix("Мои заметки\n"))
    }

    /// A color reset on one device (no overrides left) is reset on the others too, not kept from their copy.
    @Test func aRemovedColorStaysRemovedOnOtherDevices() async throws {
        var colored = TestConfig.defaults
        colored.colors = ["task": "#111111"]
        #expect(SyncedSettings.merged(note: Data(#"{"colors":{}}"#.utf8), over: colored).colors.isEmpty)

        let sandbox = try VaultSandbox.make()
        let note = settingsNote(in: sandbox)
        try await note.write(try JSONEncoder.store.encode(SyncedSettings(TestConfig.defaults)))
        let back = try #require(await note.read())
        #expect(SyncedSettings.merged(note: back, over: colored).colors.isEmpty)
    }

    private func settingsNote(in sandbox: VaultSandbox) -> VaultSettingsNote {
        VaultSettingsNote(location: FixedVaultLocation(url: sandbox.vault), fileSystem: CoordinatedFileSystem(),
                          fileName: "SuperPooper Settings.md", vaultSettings: { TestConfig.defaults.vault })
    }

    private func noteURL(in sandbox: VaultSandbox) -> URL {
        sandbox.vault.appendingPathComponent("TaskNotes/SuperPooper Settings.md")
    }
}
