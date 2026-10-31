import Foundation
import Testing
@testable import SuperPooperApp

/// Links, renaming, trash and backups on a rendered copy of the test vault.
@Suite("Note operations")
struct NoteOperationsTests {
    // MARK: - previous_task

    @Test func aNewPreviousTaskIsWrittenAsATaskNotesObject() async throws {
        let note = try await SandboxNote("Повесить зеркало")
        let original = try note.text()
        try await note.apply([.addPreviousTask("Купить батарейки 🔋")])
        expectSameBytes(try note.text(), try original
            .replacingOnce("    reltype: FINISHTOSTART\n",
                           with: "    reltype: FINISHTOSTART\n  - uid: \"[[Купить батарейки 🔋]]\"\n    reltype: FINISHTOSTART\n")
            .replacingOnce("date_modified: 2026-10-20T09:12:44.123+02:00", with: "date_modified: \(note.sandbox.nowStamp)"))
        #expect(note.task.previousTasks == ["Собрать шкаф", "Купить батарейки 🔋"])
    }

    @Test func existingEntriesAreKeptAsTheyWere() async throws {
        let sandbox = try VaultSandbox.make()
        try sandbox.write(Self.mixedLinks, to: "Связи разных видов")
        let note = try await SandboxNote("Связи разных видов", sandbox: sandbox)
        #expect(note.task.previousTasks == ["Найти отвёртку", "Собрать шкаф", "Купить батарейки 🔋"])

        try await note.apply([.addPreviousTask("Повесить зеркало")])
        expectSameBytes(try note.text(), try Self.mixedLinks
            .replacingOnce("  - Купить батарейки 🔋\n",
                           with: "  - Купить батарейки 🔋\n  - uid: \"[[Повесить зеркало]]\"\n    reltype: FINISHTOSTART\n")
            .replacingOnce("date_modified: 2026-10-20T09:12:44.123+02:00", with: "date_modified: \(sandbox.nowStamp)"))

        try await note.apply([.removePreviousTask("Собрать шкаф"), .removePreviousTask("Повесить зеркало")])
        expectSameBytes(try note.text(), try Self.mixedLinks
            .replacingOnce("  - \"[[Собрать шкаф]]\"\n", with: "")
            .replacingOnce("date_modified: 2026-10-20T09:12:44.123+02:00", with: "date_modified: \(sandbox.nowStamp)"))

        try await note.apply([.removePreviousTask("Найти отвёртку"), .removePreviousTask("купить БАТАРЕЙКИ 🔋")])
        let withoutLinks = try #require(Self.mixedLinks.components(separatedBy: "previous_task:").first)
            + "date_modified: \(sandbox.nowStamp)\n---\nТело заметки\n"
        expectSameBytes(try note.text(), withoutLinks)
    }

    // MARK: - Rename

    @Test func renameMovesTheFileAndRewritesLinksOfDependents() async throws {
        let sandbox = try VaultSandbox.make()
        let repository = sandbox.repository()
        let tasks = try await repository.load().tasks
        let screwdriver = try #require(tasks.first { $0.name == "Найти отвёртку" })
        let dependents = tasks.filter { $0.previousTasks.contains("Найти отвёртку") }
        #expect(dependents.map(\.name).sorted() == ["Связь без скобок", "Собрать шкаф"])
        let content = try sandbox.text(of: "Найти отвёртку")
        let wardrobe = try sandbox.text(of: "Собрать шкаф")
        let plain = try sandbox.text(of: "Связь без скобок")

        let renamed = try await repository.rename(screwdriver, to: "Найти отвёртку 🪛", dependents: dependents)

        #expect(renamed.name == "Найти отвёртку 🪛" && renamed.relativePath == "TaskNotes/Tasks/Найти отвёртку 🪛.md")
        #expect(!sandbox.exists("Найти отвёртку"))
        expectSameBytes(try sandbox.text(of: "Найти отвёртку 🪛"), content)
        let newLink = "  - uid: \"[[Найти отвёртку 🪛]]\"\n    reltype: FINISHTOSTART\n"
        let stamp = "date_modified: \(sandbox.nowStamp)"
        expectSameBytes(try sandbox.text(of: "Собрать шкаф"), try wardrobe
            .replacingOnce("  - uid: \"[[Найти отвёртку]]\"\n    reltype: FINISHTOSTART\n", with: newLink)
            .replacingOnce("date_modified: 2026-10-20T09:12:44.123+02:00", with: stamp))
        expectSameBytes(try sandbox.text(of: "Связь без скобок"), try plain
            .replacingOnce("  - Найти отвёртку\n", with: newLink)
            .replacingOnce("date_modified: 2026-10-20T09:12:44.123+02:00", with: stamp))

        let plan = DayScenario(tasks: try await repository.load().tasks).build()
        #expect(plan.problems(of: "Собрать шкаф").isEmpty && plan.problems(of: "Связь без скобок").isEmpty)
        #expect(plan.item(named: "Собрать шкаф")?.blockers == [.task("Найти отвёртку 🪛")])
    }

    @Test func aTakenOrInvalidNameIsRejectedWithoutTouchingFiles() async throws {
        let sandbox = try VaultSandbox.make()
        let repository = sandbox.repository()
        let batteries = try #require(try await repository.load().tasks.first { $0.name == "Купить батарейки 🔋" })
        let before = try sandbox.text(of: "Купить батарейки 🔋")

        await #expect(throws: TaskStoreError.nameTaken("найти отвёртку")) {
            try await repository.rename(batteries, to: "найти отвёртку", dependents: [])
        }
        for name in ["", " Пробел в начале", "Папка/Задача", "[[Ссылка]]", "Вопрос?", ".hidden", "Хэш#тег"] {
            await #expect(throws: TaskStoreError.invalidName(name)) {
                try await repository.rename(batteries, to: name, dependents: [])
            }
        }
        expectSameBytes(try sandbox.text(of: "Купить батарейки 🔋"), before)
        #expect(try FileManager.default.contentsOfDirectory(atPath: sandbox.tasksFolder.path).count == 38)
    }

    // MARK: - Trash

    @Test func moveToTrashMovesTheNoteIntoTheVaultTrashFolder() async throws {
        let sandbox = try VaultSandbox.make()
        let repository = sandbox.repository()
        let ideas = try #require(try await repository.load().tasks.first { $0.name == "Записать идеи" })
        let content = try sandbox.text(of: "Записать идеи")

        try await repository.delete(ideas)
        #expect(!sandbox.exists("Записать идеи"))
        let trashed = sandbox.trashFolder.appendingPathComponent("Записать идеи.md")
        expectSameBytes(try String(contentsOf: trashed, encoding: .utf8), content)
        #expect(try await repository.load().tasks.count == 35)

        try sandbox.write("---\ntags:\n  - 🔫делишка\nstatus: this_week\n---\nВторая\n", to: "Записать идеи")
        try await repository.delete(ideas)
        let second = sandbox.trashFolder.appendingPathComponent("Записать идеи 1.md")
        #expect(try String(contentsOf: second, encoding: .utf8).hasSuffix("Вторая\n"))
        expectSameBytes(try String(contentsOf: trashed, encoding: .utf8), content)
    }

    // MARK: - Backups

    @Test func backupCopiesTheNotesAndKeepsOnlyTheNewestFolders() async throws {
        let sandbox = try VaultSandbox.make()
        let repository = sandbox.repository(keepBackups: 2)
        let tasks = try await repository.load().tasks
        let picked = tasks.filter { ["Найти отвёртку", "Медитация 🧘"].contains($0.name) }

        try await repository.backup(picked, reason: "first")
        let firstFolder = try #require(try backupFolders(sandbox).first)
        #expect(firstFolder.hasSuffix("-first"))
        let copied = sandbox.backups.appendingPathComponent(firstFolder)
        #expect(try FileManager.default.contentsOfDirectory(atPath: copied.path).sorted() == ["Медитация 🧘.md", "Найти отвёртку.md"])
        expectSameBytes(try String(contentsOf: copied.appendingPathComponent("Медитация 🧘.md"), encoding: .utf8),
                        try sandbox.text(of: "Медитация 🧘"))

        try await repository.backup(picked, reason: "second")
        try await repository.backup(picked, reason: "third")
        #expect(try backupFolders(sandbox).map { $0.components(separatedBy: "-").last ?? "" } == ["second", "third"])
        #expect(sandbox.exists("Найти отвёртку") && sandbox.exists("Медитация 🧘"))
    }

    /// Named by the UTC time, whatever the phone's zone: the newest backup always sorts last and is never rotated away.
    @Test func backupFoldersAreNamedInUTC() throws {
        let sandbox = try VaultSandbox.make()
        let moment = try #require(ISO8601.parse("2026-10-21T00:30:00Z"))
        let service = BackupService(directory: sandbox.backups, keepCount: 1, fileSystem: CoordinatedFileSystem(), clock: { moment },
                                    calendar: FixedCalendar(current: TestCalendar.calendar))
        let folder = try #require(try service.backup([sandbox.url(of: "Найти отвёртку")], reason: "first"))
        #expect(folder.lastPathComponent == "20261021T003000.000Z-first")
    }

    /// Folders of older versions are named by the phone's clock. In Jakarta just after midnight their date is already
    /// the 22nd while the new UTC names still say the 21st: by name the newest backup sorted oldest and was rotated away.
    @Test func rotationGoesByTheMomentInTheNameOfBothKinds() throws {
        let sandbox = try VaultSandbox.make()
        let jakarta = FixedCalendar(current: TestCalendar.calendar(in: "Asia/Jakarta"))
        for legacy in ["20261022-003000-000-older", "20261022-010000-000-newer"] {
            try FileManager.default.createDirectory(at: sandbox.backups.appendingPathComponent(legacy), withIntermediateDirectories: true)
        }
        let moment = try #require(ISO8601.parse("2026-10-21T18:30:00Z"))
        let service = BackupService(directory: sandbox.backups, keepCount: 2, fileSystem: CoordinatedFileSystem(), clock: { moment },
                                    calendar: jakarta)
        try service.backup([sandbox.url(of: "Найти отвёртку")], reason: "newest")
        #expect(try backupFolders(sandbox) == ["20261021T183000.000Z-newest", "20261022-010000-000-newer"])
    }

    @Test func aFolderNameGivesTheMomentOfTheBackup() throws {
        let belgrade = TestCalendar.timeZone
        #expect(BackupFolderName.moment(of: "20261021T003000.250Z-delete", legacyZone: belgrade)
                == ISO8601.parse("2026-10-21T00:30:00.250Z"))
        #expect(BackupFolderName.moment(of: "20261021-023000-000-rename", legacyZone: belgrade) == ISO8601.parse("2026-10-21T00:30:00Z"))
        #expect(BackupFolderName.moment(of: "notes", legacyZone: belgrade) == nil)
    }

    @Test func obsidianLinkOpensTheNoteInTheVault() async throws {
        let sandbox = try VaultSandbox.make()
        let repository = sandbox.repository()
        let task = try #require(try await repository.load().tasks.first { $0.name == "Утро — душ 🚿" })
        let url = try #require(await repository.externalURL(for: task))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "obsidian" && components.host == "open")
        #expect(components.queryItems == [URLQueryItem(name: "vault", value: "Vault"),
                                          URLQueryItem(name: "file", value: "TaskNotes/Tasks/Утро — душ 🚿")])
    }

    // MARK: - Helpers

    private static let mixedLinks = """
    ---
    tags:
      - 🔫делишка
    status: this_week
    previous_task:
      - uid: "[[Найти отвёртку]]"
        reltype: STARTTOSTART
        gap: P1D
      - "[[Собрать шкаф]]"
      - Купить батарейки 🔋
    date_modified: 2026-10-20T09:12:44.123+02:00
    ---
    Тело заметки

    """

    private func backupFolders(_ sandbox: VaultSandbox) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: sandbox.backups.path).filter { !$0.hasPrefix(".") }.sorted()
    }
}

/// Subtasks are TaskNotes `projects` links to the parent note.
@Suite("Subtask links")
struct SubtaskLinkTests {
    @Test func projectsAreReadAsParentNames() async throws {
        let note = try await SandboxNote("Длинная заметка с незнакомыми ключами")
        #expect(note.task.projects == ["Ремонт"])
    }

    @Test func aSubtaskGetsItsParentInProjectsOnce() async throws {
        let note = try await SandboxNote("Повесить зеркало")
        try await note.apply([.addProject("Ремонт"), .addProject("ремонт")])
        #expect(note.task.projects == ["Ремонт"])
        #expect(try note.text().contains("projects:\n  - \"[[Ремонт]]\"\n"))

        try await note.apply([.renameProject(from: "Ремонт", to: "Ремонт кухни")])
        #expect(note.task.projects == ["Ремонт кухни"])
        #expect(try note.text().contains("  - \"[[Ремонт кухни]]\"\n"))
    }
}
