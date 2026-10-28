import Foundation
import Testing
@testable import SuperPooperApp

/// Restoring from the vault's trash.
@Suite("Trash")
struct TrashTests {
    /// A note in iCloud that is not downloaded yet (`.Name.md.icloud`) still takes its name.
    @Test func aRestoredNoteDoesNotTakeTheNameOfAnUndownloadedNote() async throws {
        let sandbox = try VaultSandbox.make()
        let text = try String(contentsOf: sandbox.url(of: "Купить молоко"), encoding: .utf8)
        let trash = sandbox.vault.appendingPathComponent(".trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        try text.write(to: trash.appendingPathComponent("Задача.md"), atomically: true, encoding: .utf8)
        try Data().write(to: sandbox.tasksFolder.appendingPathComponent(".Задача.md.icloud"))

        let repository = VaultTrashRepository(location: FixedVaultLocation(url: sandbox.vault), fileSystem: CoordinatedFileSystem(),
                                              noteExtension: TestConfig.rules.vault.noteExtension, vaultSettings: { TestConfig.defaults.vault })
        let note = try #require(try await repository.notes().first { $0.name == "Задача" })
        #expect(try await repository.restore(note) == "Задача 2")
    }

    @Test func aFreeNameGetsTheNextNumber() {
        let taken: Set<String> = ["Note", "Note 2", "Trash 1"]
        #expect(UniqueName.free("Other") { taken.contains($0) } == "Other")
        #expect(UniqueName.free("Note") { taken.contains($0) } == "Note 3")
        #expect(UniqueName.free("Trash", firstNumber: 1) { taken.contains($0) || $0 == "Trash" } == "Trash 2")
    }
}
