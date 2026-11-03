import Foundation
import Testing
@testable import SuperPooperApp

/// Scanning the rendered test vault with the real coordinated file system (iCloud faked).
/// The vault is rendered for Wednesday 2026-10-21 in Europe/Belgrade (UTC+2 that week).
@Suite("Vault scanning")
struct VaultScannerTests {
    @Test func everyTaggedNoteIsATaskAndBrokenYAMLIsAFileProblem() async throws {
        let sandbox = try VaultSandbox.make()
        let result = await sandbox.scan()

        #expect(result.tasks.count == 38)
        #expect(Set(result.tasks.map(\.name)) == Self.taskNames)
        #expect(!result.tasks.contains { $0.name == "Просто заметка без тега" })
        #expect(result.conflicted.isEmpty)
        #expect(result.fileProblems.count == 1)
        guard case .brokenYAML(let file, _) = try #require(result.fileProblems.first) else {
            Issue.record("Expected a broken YAML problem, got \(result.fileProblems)")
            return
        }
        #expect(file == "Битый YAML")
        #expect(result.tasks.allSatisfy { $0.id.relativePath == "TaskNotes/Tasks/\($0.name).md" })
    }

    @Test func onlyTheUnknownRuleNoteHasAReadProblem() async throws {
        let tasks = try await scannedTasks()
        let withProblems = tasks.filter { !$0.problems.isEmpty }
        #expect(withProblems.map(\.name) == ["Неизвестное правило"])
        let unknown = try #require(withProblems.first)
        #expect(unknown.problems == [.unknownRecurrence("FREQ=HOURLY;INTERVAL=2")])
        #expect(unknown.isHabit && unknown.recurrence == nil)
    }

    // MARK: - Exact fields

    @Test func aHabitWithHistoryIsReadExactly() async throws {
        let task = try await scanned("Медитация 🧘")
        var expected = TaskItem(id: TaskID("TaskNotes/Tasks/Медитация 🧘.md"), name: "Медитация 🧘", status: .halfYear)
        expected.timeEstimate = 15
        expected.recurrence = try RecurrenceCodec.parse("DTSTART:20260921;FREQ=DAILY;INTERVAL=1").get()
        expected.marks = [LocalDate("2026-10-15"): .done, LocalDate("2026-10-16"): .partial, LocalDate("2026-10-17"): .done,
                          LocalDate("2026-10-19"): .twice, LocalDate("2026-10-20"): .done]
        try expectSame(task, expected, created: "2026-09-21", modified: "2026-10-20")
    }

    @Test func aTimedHabitIsReadExactly() async throws {
        let task = try await scanned("Витамины 💊")
        #expect(task.due == TaskDue("2026-09-21T09:00"))
        #expect(task.recurrence?.frequency == .daily && task.recurrence?.startDate == LocalDate("2026-09-21"))
        #expect(task.recurrence?.startTime == LocalTime("09:00"))
        #expect(task.marks.isEmpty && task.timeEstimate == 2)
    }

    @Test func flagsDatesAndStatusesAreRead() async throws {
        let tasks = try await tasksByName()
        let mail = try #require(tasks["Разобрать почту"])
        #expect(mail.feel == .needEnergy && mail.timeEstimate == 60)
        #expect(tasks["Посмотреть сериал 🍿"]?.feel == .pleasant)
        #expect(tasks["Позвонить в банк"]?.isHighPriority == true)
        #expect(tasks["Записать идеи"]?.timeEstimate == nil)
        #expect(tasks["Забрать посылку на почте"]?.due == TaskDue("2026-10-21T16:00"))
        #expect(tasks["Оплатить интернет"]?.due == TaskDue("2026-10-21"))
        #expect(tasks["Сдать отчёт"]?.due == TaskDue("2026-10-23"))
        #expect(tasks["Обновить резюме"]?.due == TaskDue("2026-10-25"))
        #expect(tasks["Купить молоко"]?.status == .done)
        #expect(tasks["Купить молоко"]?.completedDate == LocalDate("2026-10-21"))
        #expect(tasks["Ждать ответа от арендодателя"]?.status == .waiting)
        #expect(tasks["Архивная задача"]?.status == .archived)
        #expect(tasks["Выучить испанский"]?.status == .someday)
    }

    @Test func unknownKeysDoNotDisturbReading() async throws {
        let task = try await scanned("Длинная заметка с незнакомыми ключами")
        var expected = TaskItem(id: TaskID("TaskNotes/Tasks/Длинная заметка с незнакомыми ключами.md"), name: "Длинная заметка с незнакомыми ключами", status: .thisWeek)
        expected.timeEstimate = 15
        // `projects` is read: it makes the note a TaskNotes subtask of «Ремонт».
        expected.projects = ["Ремонт"]
        try expectSame(task, expected, created: "2026-10-06", modified: "2026-10-19")
    }

    /// The trash, `.obsidian` and other hidden folders are not part of the tasks, even when the chosen tasks
    /// folder is the vault root itself.
    @Test func hiddenFoldersAreNotScanned() async throws {
        let sandbox = try VaultSandbox.make()
        let note = try String(contentsOf: sandbox.url(of: "Купить молоко"), encoding: .utf8)
        let trash = sandbox.vault.appendingPathComponent(".trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        try note.write(to: trash.appendingPathComponent("Удалённая.md"), atomically: true, encoding: .utf8)
        let output = await sandbox.scanner().scan(root: sandbox.vault, tasksFolder: "")
        #expect(!output.result.tasks.map(\.name).contains("Удалённая"))
        #expect(output.result.tasks.map(\.name).contains("Купить молоко"))
    }

    @Test func aMissingTasksFolderIsAFileProblem() async throws {
        let sandbox = try VaultSandbox.make()
        let output = await sandbox.scanner().scan(root: sandbox.vault, tasksFolder: "Nowhere/Tasks")
        #expect(output.result.tasks.isEmpty)
        #expect(output.result.fileProblems == [.tasksFolderMissing("Nowhere/Tasks")])
    }

    // MARK: - Helpers

    static let taskNames: Set<String> = [
        "Архивная задача", "Витамины 💊", "Выпить воды 💧", "Выучить испанский", "Длинная заметка с незнакомыми ключами",
        "Ждать ответа от арендодателя", "Входящая мысль", "Забрать посылку на почте", "Записать идеи", "Записать итоги разговора",
        "Купить батарейки 🔋", "Купить молоко", "Медитация 🧘", "Найти отвёртку", "Неизвестное правило", "Обновить резюме",
        "Оплатить интернет", "Повесить зеркало", "Подготовить вопросы папе", "Позвонить в банк", "Полить цветы 🌱",
        "Помыть окна", "Посмотреть сериал 🍿", "Прогулка 🚶", "Разобрать почту", "Распечатать вопросы", "Связь без скобок",
        "Связь на несуществующую", "Сдать отчёт", "Собрать шкаф", "Старая сделанная задача", "Стирка 🧺",
        "Сходить к стоматологу", "Утро — душ 🚿", "Утро — завтрак 🥣", "Утро — зарядка 🤸", "Цикл А", "Цикл Б",
    ]

    private func scannedTasks() async throws -> [TaskItem] {
        try await VaultSandbox.make().scan().tasks
    }

    private func tasksByName() async throws -> [String: TaskItem] {
        Dictionary(try await scannedTasks().map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func scanned(_ name: String) async throws -> TaskItem {
        try #require(try await tasksByName()[name])
    }

    /// Compares every field; the fixture timestamps are `YYYY-MM-DDT09:12:44.123+02:00`.
    private func expectSame(_ task: TaskItem, _ expected: TaskItem, created: String, modified: String,
                            sourceLocation: SourceLocation = #_sourceLocation) throws {
        let stamp = { (day: String) in TestCalendar.date(day, "09:12").addingTimeInterval(44.123) }
        let createdDate = try #require(task.dateCreated, sourceLocation: sourceLocation)
        let modifiedDate = try #require(task.dateModified, sourceLocation: sourceLocation)
        #expect(abs(createdDate.timeIntervalSince(stamp(created))) < 0.001, sourceLocation: sourceLocation)
        #expect(abs(modifiedDate.timeIntervalSince(stamp(modified))) < 0.001, sourceLocation: sourceLocation)
        #expect(task.created == TaskDue("\(created)T09:12"), sourceLocation: sourceLocation)
        var comparable = expected
        comparable.dateCreated = task.dateCreated
        comparable.created = task.created
        comparable.dateModified = task.dateModified
        #expect(task == comparable, sourceLocation: sourceLocation)
    }
}
