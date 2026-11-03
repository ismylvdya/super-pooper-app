import Foundation
import Testing
@testable import SuperPooperApp

/// The ```SuperPooperApp block in old note bodies and the settings file in the chosen folder.
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
        #expect(!(try await reloaded.repository.text(of: reloaded.task)).contains("SuperPooperApp"))
        _ = try await reloaded.repository.setText("Новый текст\n", of: reloaded.task)
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

    /// The shared settings are a JSON file in the chosen folder, pretty-printed.
    @Test func theSettingsFileIsWrittenAndRead() async throws {
        let sandbox = try VaultSandbox.make()
        let file = VaultSettingsFile(location: FixedVaultLocation(url: sandbox.vault), fileSystem: CoordinatedFileSystem(),
                                     fileName: "super-pooper-app-settings.json")
        #expect(await file.read() == nil)
        var settings = TestConfig.defaults
        settings.appearance.pastOpacity = 0.3
        try await file.write(try JSONEncoder.store.encode(SyncedSettings(settings)))
        let json = try String(contentsOf: sandbox.vault.appendingPathComponent("super-pooper-app-settings.json"), encoding: .utf8)
        #expect(json.hasPrefix("{\n"))
        let back = try #require(await file.read())
        #expect(SyncedSettings.merged(note: back, over: TestConfig.defaults).appearance.pastOpacity == 0.3)
    }
}
