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

    @Test func theSettingsNoteRoundTrips() async throws {
        let sandbox = try VaultSandbox.make()
        let note = VaultSettingsNote(location: FixedVaultLocation(url: sandbox.vault), fileSystem: CoordinatedFileSystem(),
                                     fileName: "SuperPooper Settings.md", vaultSettings: { TestConfig.defaults.vault })
        #expect(await note.read() == nil)
        let json = try JSONEncoder.store.encode(SyncedSettings(TestConfig.defaults))
        try await note.write(json)
        #expect(await note.read() == json)
        let url = sandbox.vault.appendingPathComponent("TaskNotes/SuperPooper Settings.md")
        #expect(try String(contentsOf: url, encoding: .utf8).hasPrefix("```SuperPooperApp\n"))
    }
}
