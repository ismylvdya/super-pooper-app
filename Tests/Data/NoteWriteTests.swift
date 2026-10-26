import Foundation
import Testing
@testable import SuperPooper

/// Writing through `VaultTaskRepository` into a rendered copy of the test vault: only the changed keys
/// and `date_modified` may differ, byte for byte (`<data_model>` "Запись в файлы").
/// The vault is rendered for Wednesday 2026-10-21; "now" is 13:25 Belgrade time.
@Suite("Note writing")
struct NoteWriteTests {
    // MARK: - One key changes, everything else stays

    @Test func changingOneFieldOfTheLongNoteKeepsEveryOtherByte() async throws {
        let note = try await SandboxNote("Длинная заметка с незнакомыми ключами")
        let original = try note.text()
        let body = try #require(splitNote(original)).body
        let template = try String(contentsOf: TestPaths.testVault.appendingPathComponent(
            "TaskNotes/Tasks/Длинная заметка с незнакомыми ключами.md"), encoding: .utf8)
        #expect(body == (try #require(splitNote(template))).body)
        #expect(body.hasPrefix("# Заметка с длинным телом\n") && body.hasSuffix("да выпей чаю. 🥐\n"))

        _ = try await note.apply([.highPriority(true)])

        let expectedFrontmatter = """
        ---
        tags:
          - 🔫делишка
        status: this_week
        priority: high
        # комментарий пользователя — должен сохраниться
        time_estimate: 15
        contexts:
          - home
        projects:
          - "[[Ремонт]]"
        custom_map:
          nested: значение
          list:
            - 1
            - 2
        description: |
          Многострочный текст
          на две строки
        recurrence_anchor: scheduled
        skipped_instances: []
        deadline: 2026-11-20
        date_created: 2026-10-06T09:12:44.123+02:00
        date_modified: \(note.sandbox.nowStamp)
        ---

        """
        expectSameBytes(try note.text(), expectedFrontmatter + body)
    }

    @Test func eachFieldEditTouchesOnlyItsOwnLines() async throws {
        let note = try await SandboxNote("Длинная заметка с незнакомыми ключами")
        let original = try note.text()
        let modified = "date_modified: 2026-10-19T09:12:44.123+02:00\n"
        let written = "date_modified: \(note.sandbox.nowStamp)\n"

        _ = try await note.apply([.timeEstimate(60), .status(.halfYear)])
        expectSameBytes(try note.text(), try original
            .replacingOnce("time_estimate: 15\n", with: "time_estimate: 60\n")
            .replacingOnce("status: this_week\n", with: "status: half_year\n")
            .replacingOnce(modified, with: written))

        _ = try await note.apply([.timeEstimate(15), .status(.thisWeek), .needEnergy(true), .due(TaskDue("2026-10-23T16:00"))])
        expectSameBytes(try note.text(), try original
            .replacingOnce(modified, with: written + "need_energy: true\ndue: 2026-10-23T16:00\n"))

        _ = try await note.apply([.needEnergy(false), .due(nil), .pleasant(false)])
        expectSameBytes(try note.text(), try original
            .replacingOnce(modified, with: written + "need_energy: false\npleasant: false\n"))
    }

    /// A change counts (and gets its banner) only once the file read back shows it: a write that did not land fails.
    @Test func aWriteThatDidNotLandIsNotTakenForDone() async throws {
        let sandbox = try VaultSandbox.make()
        let repository = sandbox.repository(fileSystem: LosingFileSystem())
        let task = try #require(try await repository.scan().tasks.first { $0.name == "Оплатить интернет" })
        await #expect(throws: TaskRepositoryError.notConfirmed("Оплатить интернет")) {
            try await repository.apply([.highPriority(true)], to: task)
        }
        await #expect(throws: TaskRepositoryError.notConfirmed("Оплатить интернет 2")) {
            try await repository.rename(task, to: "Оплатить интернет 2", dependents: [])
        }
        await #expect(throws: TaskRepositoryError.notConfirmed("Новое дело")) {
            try await repository.create(named: "Новое дело", status: .thisWeek)
        }
    }

    @Test func editingTheBodyKeepsTheFrontmatter() async throws {
        let note = try await SandboxNote("Длинная заметка с незнакомыми ключами")
        let frontmatter = try #require(splitNote(try note.text())).frontmatter
        _ = try await note.repository.setBody("Новый текст 📝\n", of: note.task)
        expectSameBytes(try note.text(), try frontmatter
            .replacingOnce("date_modified: 2026-10-19T09:12:44.123+02:00", with: "date_modified: \(note.sandbox.nowStamp)")
            + "Новый текст 📝\n")
        #expect(try await note.repository.body(of: note.task) == "Новый текст 📝\n")
    }

    // MARK: - Habit marks

    @Test func habitMarksWriteExactlyTheListsOfTheSpec() async throws {
        let note = try await SandboxNote("Медитация 🧘")
        let history = ["2026-10-15", "2026-10-16", "2026-10-17", "2026-10-19", "2026-10-20"]
        expectSameBytes(try note.text(), meditation(complete: history, partial: ["2026-10-16"], twice: ["2026-10-19"],
                                                    modified: "2026-10-20T09:12:44.123+02:00"))
        let now = note.sandbox.nowStamp

        try await note.mark(.twice)
        expectSameBytes(try note.text(), meditation(complete: history + ["2026-10-21"], partial: ["2026-10-16"],
                                                    twice: ["2026-10-19", "2026-10-21"], modified: now))
        try await note.mark(.partial)
        expectSameBytes(try note.text(), meditation(complete: history + ["2026-10-21"], partial: ["2026-10-16", "2026-10-21"],
                                                    twice: ["2026-10-19"], modified: now))
        try await note.mark(.done)
        expectSameBytes(try note.text(), meditation(complete: history + ["2026-10-21"], partial: ["2026-10-16"],
                                                    twice: ["2026-10-19"], modified: now))
        try await note.mark(nil)
        expectSameBytes(try note.text(), meditation(complete: history, partial: ["2026-10-16"], twice: ["2026-10-19"], modified: now))
    }

    @Test func anEmptyCompleteListIsFilledInPlaceAndEmptiedBackToBrackets() async throws {
        let note = try await SandboxNote("Утро — зарядка 🤸")
        let original = try note.text()
        let modified = "date_modified: 2026-10-20T09:12:44.123+02:00\n"
        let written = "date_modified: \(note.sandbox.nowStamp)\n"

        try await note.mark(.done)
        expectSameBytes(try note.text(), try original
            .replacingOnce("complete_instances: []\n", with: "complete_instances:\n  - 2026-10-21\n")
            .replacingOnce(modified, with: written))
        try await note.mark(nil)
        expectSameBytes(try note.text(), try original.replacingOnce(modified, with: written))
    }

    @Test func extraListsAreAddedWhenNeededAndRemovedWhenEmpty() async throws {
        let note = try await SandboxNote("Выпить воды 💧")
        let original = try note.text()
        let modified = "date_modified: 2026-10-20T09:12:44.123+02:00\n"
        let written = "date_modified: \(note.sandbox.nowStamp)\n"
        let marked = try original.replacingOnce("  - 2026-10-20\n", with: "  - 2026-10-20\n  - 2026-10-21\n")

        try await note.mark(.partial)
        expectSameBytes(try note.text(), try marked.replacingOnce(modified, with: written + "partial_instances:\n  - 2026-10-21\n"))
        try await note.mark(.twice)
        expectSameBytes(try note.text(), try marked.replacingOnce(modified, with: written + "twice_instances:\n  - 2026-10-21\n"))
        try await note.mark(nil)
        expectSameBytes(try note.text(), try original.replacingOnce(modified, with: written))
    }

    // MARK: - Regular tasks

    @Test func doneSetsStatusAndCompletedDateAndUndoRemovesThem() async throws {
        let note = try await SandboxNote("Найти отвёртку")
        let original = try note.text()
        let modified = "date_modified: 2026-10-20T09:12:44.123+02:00\n"
        let written = "date_modified: \(note.sandbox.nowStamp)\n"

        let done = try await note.mark(.done)
        expectSameBytes(try note.text(), try original
            .replacingOnce("status: this_week\n", with: "status: done\n")
            .replacingOnce(modified, with: written + "completed_date: 2026-10-21\n"))
        #expect(done.status == .done && done.completedDate == LocalDate("2026-10-21"))

        let undone = try await note.mark(nil)
        expectSameBytes(try note.text(), try original.replacingOnce(modified, with: written))
        #expect(undone.status == .thisWeek && undone.completedDate == nil)
    }

    @Test func undoingATaskDoneTodayRemovesItsCompletedDateLine() async throws {
        let note = try await SandboxNote("Купить молоко")
        let original = try note.text()
        try await note.mark(nil)
        expectSameBytes(try note.text(), try original
            .replacingOnce("status: done\n", with: "status: this_week\n")
            .replacingOnce("completed_date: 2026-10-21\n", with: "")
            .replacingOnce("date_modified: 2026-10-21T09:12:44.123+02:00\n", with: "date_modified: \(note.sandbox.nowStamp)\n"))
    }

    @Test func aBrokenOrMissingFileIsAnErrorAndNothingIsWritten() async throws {
        let sandbox = try VaultSandbox.make()
        let repository = sandbox.repository()
        let broken = TaskNote(name: "Битый YAML", relativePath: "TaskNotes/Tasks/Битый YAML.md", status: .thisWeek)
        let original = try sandbox.text(of: "Битый YAML")
        await #expect(throws: TaskRepositoryError.brokenFrontmatter("Битый YAML")) {
            try await repository.apply([.highPriority(true)], to: broken)
        }
        #expect(try sandbox.text(of: "Битый YAML") == original)
        let missing = TaskNote(name: "Нет такой", relativePath: "TaskNotes/Tasks/Нет такой.md", status: .thisWeek)
        await #expect(throws: TaskRepositoryError.fileMissing("Нет такой")) {
            try await repository.apply([.highPriority(true)], to: missing)
        }
        #expect(!sandbox.exists("Нет такой"))
    }

    // MARK: - Helpers

    private func meditation(complete: [String], partial: [String], twice: [String], modified: String) -> String {
        func list(_ key: String, _ days: [String]) -> String { "\(key):\n" + days.map { "  - \($0)\n" }.joined() }
        return "---\ntags:\n  - 🔫делишка\nstatus: half_year\npriority: none\n"
            + "recurrence: DTSTART:20260921;FREQ=DAILY;INTERVAL=1\nrecurrence_anchor: scheduled\n"
            + list("complete_instances", complete) + list("partial_instances", partial) + list("twice_instances", twice)
            + "time_estimate: 15\ndate_created: 2026-09-21T09:12:44.123+02:00\ndate_modified: \(modified)\n---\n"
    }
}

/// A disk that says yes to every write and move but keeps nothing.
private struct LosingFileSystem: NoteFileSystem {
    private let real = CoordinatedFileSystem()

    func listFiles(in folder: URL) throws -> [URL] { try real.listFiles(in: folder) }
    func read(_ url: URL) throws -> NoteFile { try real.read(url) }
    func modificationDate(of url: URL) -> Date? { real.modificationDate(of: url) }
    func write(_ text: String, to url: URL) throws {}
    func move(_ url: URL, to destination: URL) throws {}
    func copy(_ url: URL, to destination: URL) throws { try real.copy(url, to: destination) }
    func fileExists(_ url: URL) -> Bool { real.fileExists(url) }
    func remove(_ url: URL) throws {}
}
