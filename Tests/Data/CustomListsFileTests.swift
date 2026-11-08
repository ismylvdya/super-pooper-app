import Foundation
import Testing
@testable import SuperPooperApp

/// Lists of the user's own: third-level headings in the Lists section of the tasks file.
@Suite("Custom lists in the file")
struct CustomListsFileTests {
    private let folder: URL
    private let format = TestConfig.decode(TaskFileFormat.self, TaskFileFormat.fileName)

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent(format.folder), withIntermediateDirectories: true)
    }

    private func store() -> TaskFileStore {
        let fileSystem = CoordinatedFileSystem()
        let backups = BackupService(directory: folder.appendingPathComponent("Backups"), keepCount: 2, fileSystem: fileSystem,
                                    clock: { Date() }, calendar: FixedCalendar(current: TestCalendar.calendar))
        let counter = Counter()
        return TaskFileStore(location: FixedVaultLocation(url: folder), fileSystem: fileSystem, ubiquity: FakeUbiquityService(), format: format,
                             obsidian: TestConfig.obsidian, backups: backups, rules: TestConfig.rules.vault,
                             vaultSettings: { TestConfig.defaults.vault }, today: { LocalDate("2026-10-21") },
                             lookMemory: JSONDayLookMemory(store: JSONFileStore(directory: folder.appendingPathComponent("Memory"))),
                             makeID: { counter.next() })
    }

    private var text: String {
        get throws { try String(contentsOf: folder.appendingPathComponent(format.folder).appendingPathComponent(format.file), encoding: .utf8) }
    }

    @Test func aLineUnderAListsHeadingIsInThatList() {
        let document = TaskDocument(text: """
        ## Lists
        - [ ] Loose
        ### Trip to Masha
        - [ ] Buy a gift
        ### Empty

        """, format: format)
        var statuses: [String: TaskStatus] = [:]
        document.walk { entry, section, _, _, list in
            statuses[entry.name] = entry.item(in: section, list: list, parentName: nil, order: nil, format: format).status
        }
        #expect(statuses == ["Loose": .someday, "Buy a gift": .custom("Trip to Masha")])
        #expect(document.listTitles == ["Trip to Masha", "Empty"])
    }

    @Test func aTaskMovedToANewListMakesItsHeadingAndBetweenListsMoves() async throws {
        let store = store()
        let task = try await store.create(NoteDraft(status: .someday), named: "Buy a gift")
        let moved = try await store.apply([.status(.custom("Trip"))], to: task).task
        #expect(moved.status == .custom("Trip"))
        #expect(try text.contains("## Lists\n### Trip\n- [ ] Buy a gift"))
        let again = try await store.apply([.status(.custom("Home"))], to: moved).task
        #expect(again.status == .custom("Home"))
        let loaded = try await store.load()
        #expect(loaded.customLists == ["Trip", "Home"])
        #expect(loaded.tasks.first { $0.name == "Buy a gift" }?.status == .custom("Home"))
    }

    @Test func anEmptyListIsKeptAndARemovedOnesTasksGoToSomeday() async throws {
        let store = store()
        try await store.addList("Trip")
        #expect(try await store.load().customLists == ["Trip"])
        _ = try await store.create(NoteDraft(status: .custom("Trip")), named: "Pack")
        try await store.removeList("Trip")
        let loaded = try await store.load()
        #expect(loaded.customLists.isEmpty)
        #expect(loaded.tasks.first { $0.name == "Pack" }?.status == .someday)
    }
}

extension CustomListsFileTests {
    @Test func anOlderFileGetsListsAfterSomeday() {
        let document = TaskDocument(text: "## Today\n## Next actions\n## Soon\n## Someday\n## Archive\n## Trash\n", format: format)
        #expect(document.sections.map(\.kind) == [.now, .soon, .halfYear, .someday, .lists, .archive, .trash, .done])
    }
}
