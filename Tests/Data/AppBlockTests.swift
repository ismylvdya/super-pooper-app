import Foundation
import Testing
@testable import SuperPooperApp

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

    /// A settings note whose frontmatter does not parse is left alone (not wrapped in a new frontmatter).
    @Test func aBrokenSettingsNoteIsNotOverwritten() async throws {
        let sandbox = try VaultSandbox.make()
        let url = noteURL(in: sandbox)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // The closing `---` is missing: the frontmatter cannot be told from the text.
        let broken = "---\ntimeline.hoursBefore: 2\nМои заметки\n"
        try broken.write(to: url, atomically: true, encoding: .utf8)
        let note = settingsNote(in: sandbox)
        await #expect(throws: (any Error).self) {
            try await note.write(try JSONEncoder.store.encode(SyncedSettings(TestConfig.defaults)))
        }
        #expect(try String(contentsOf: url, encoding: .utf8) == broken)
    }

    /// The shared settings go to `super-pooper-app-settings.json` next to the tasks folder; until it exists the older
    /// note is read, and the note is left as it was.
    @Test func theSettingsFileReplacesTheNote() async throws {
        let sandbox = try VaultSandbox.make()
        let url = noteURL(in: sandbox)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let old = "---\nappearance.pastOpacity: 0.5\n---\n"
        try old.write(to: url, atomically: true, encoding: .utf8)
        let file = VaultSettingsFile(location: FixedVaultLocation(url: sandbox.vault), fileSystem: CoordinatedFileSystem(),
                                     fileName: "super-pooper-app-settings.json", vaultSettings: { TestConfig.defaults.vault },
                                     legacy: settingsNote(in: sandbox))

        let fromNote = try #require(await file.read())
        #expect(SyncedSettings.merged(note: fromNote, over: TestConfig.defaults).appearance.pastOpacity == 0.5)
        let moved = try String(contentsOf: sandbox.vault.appendingPathComponent("TaskNotes/super-pooper-app-settings.json"), encoding: .utf8)
        #expect(moved.contains("\"pastOpacity\" : 0.5"))

        var settings = TestConfig.defaults
        settings.appearance.pastOpacity = 0.3
        try await file.write(try JSONEncoder.store.encode(SyncedSettings(settings)))
        let json = try String(contentsOf: sandbox.vault.appendingPathComponent("TaskNotes/super-pooper-app-settings.json"), encoding: .utf8)
        #expect(json.hasPrefix("{\n"))
        let back = try #require(await file.read())
        #expect(SyncedSettings.merged(note: back, over: TestConfig.defaults).appearance.pastOpacity == 0.3)
        #expect(try String(contentsOf: url, encoding: .utf8) == old)
    }

    private func settingsNote(in sandbox: VaultSandbox) -> VaultSettingsNote {
        VaultSettingsNote(location: FixedVaultLocation(url: sandbox.vault), fileSystem: CoordinatedFileSystem(),
                          fileName: "SuperPooper Settings.md", vaultSettings: { TestConfig.defaults.vault })
    }

    private func noteURL(in sandbox: VaultSandbox) -> URL {
        sandbox.vault.appendingPathComponent("TaskNotes/SuperPooper Settings.md")
    }
}
