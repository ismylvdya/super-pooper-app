import Foundation
import Testing
@testable import SuperPooper

/// Scanning the rendered test vault with the real coordinated file system (iCloud faked).
/// The vault is rendered for Wednesday 2026-10-21 in Europe/Belgrade (UTC+2 that week).
@Suite("Vault scanning")
struct VaultScannerTests {
    @Test func everyTaggedNoteIsATaskAndBrokenYAMLIsAFileProblem() async throws {
        let sandbox = try VaultSandbox.make()
        let result = await sandbox.scan()

        #expect(result.tasks.count == 36)
        #expect(Set(result.tasks.map(\.name)) == Self.taskNames)
        #expect(!result.tasks.contains { $0.name == "Просто заметка без тега" })
        #expect(result.conflicted.isEmpty)
        #expect(result.fileProblems.count == 1)
        guard case .brokenYAML(let file, _) = try #require(result.fileProblems.first) else {
            Issue.record("Expected a broken YAML problem, got \(result.fileProblems)")
            return
        }
        #expect(file == "Битый YAML")
        #expect(result.tasks.allSatisfy { $0.relativePath == "TaskNotes/Tasks/\($0.name).md" })
    }

    @Test func onlyTheUnknownRuleNoteHasAReadProblem() async throws {
        let tasks = try await scannedTasks()
        let withProblems = tasks.filter { !$0.problems.isEmpty }
        #expect(withProblems.map(\.name) == ["Неизвестное правило"])
        let unknown = try #require(withProblems.first)
        #expect(unknown.problems == [.unknownRecurrence("FREQ=HOURLY;INTERVAL=2")])
        #expect(unknown.isHabit && unknown.recurrence == nil)
    }

    @Test func missingLinksAndCyclesBecomePlanProblems() async throws {
        let plan = DayScenario(tasks: try await scannedTasks()).build()
        #expect(plan.problems(of: "Связь на несуществующую") == [.linkedTaskNotFound("Несуществующая задача")])
        #expect(plan.problems(of: "Цикл А") == [.dependencyCycle])
        #expect(plan.problems(of: "Цикл Б") == [.dependencyCycle])
        #expect(plan.problems(of: "Подготовить вопросы папе") == [.eventNotFound("Call with dad")])
        #expect(plan.problems(of: "Записать итоги разговора") == [.eventNotFound("Call with dad")])
        #expect(plan.problems.count == 6)
    }

    /// Without Calendar access (or with no calendars chosen) the app cannot know whether a linked event exists.
    @Test func eventLinksAreNotReportedMissingWithoutCalendars() async throws {
        var scenario = DayScenario(tasks: try await scannedTasks())
        scenario.eventsKnown = false
        let plan = scenario.build()
        #expect(plan.problems(of: "Подготовить вопросы папе").isEmpty)
        #expect(plan.problems(of: "Связь на несуществующую") == [.linkedTaskNotFound("Несуществующая задача")])
    }

    // MARK: - Exact fields

    @Test func aTaskWithAnEventLinkIsReadExactly() async throws {
        let task = try await scanned("Подготовить вопросы папе")
        var expected = TaskNote(name: "Подготовить вопросы папе", relativePath: "TaskNotes/Tasks/Подготовить вопросы папе.md", status: .thisWeek)
        expected.timeEstimate = 15
        expected.nextEvent = EventLink(eventIdentifier: "fixture-event", title: "Call with dad", start: TestCalendar.date("2026-10-21", "19:00"))
        try expectSame(task, expected, created: "2026-10-19", modified: "2026-10-20")
    }

    @Test func aHabitWithHistoryIsReadExactly() async throws {
        let task = try await scanned("Медитация 🧘")
        var expected = TaskNote(name: "Медитация 🧘", relativePath: "TaskNotes/Tasks/Медитация 🧘.md", status: .halfYear)
        expected.timeEstimate = 15
        expected.recurrenceRaw = "DTSTART:20260921;FREQ=DAILY;INTERVAL=1"
        expected.recurrence = try RecurrenceRule.parse("DTSTART:20260921;FREQ=DAILY;INTERVAL=1").get()
        expected.completeInstances = ["2026-10-15", "2026-10-16", "2026-10-17", "2026-10-19", "2026-10-20"].map { LocalDate($0) }
        expected.partialInstances = [LocalDate("2026-10-16")]
        expected.twiceInstances = [LocalDate("2026-10-19")]
        try expectSame(task, expected, created: "2026-09-21", modified: "2026-10-20")
    }

    @Test func aTimedHabitIsReadExactly() async throws {
        let task = try await scanned("Витамины 💊")
        #expect(task.due == TaskDue("2026-09-21T09:00"))
        #expect(task.recurrence?.frequency == .daily && task.recurrence?.startDate == LocalDate("2026-09-21"))
        #expect(task.recurrence?.startTime == LocalTime("09:00"))
        #expect(task.completeInstances.isEmpty && task.timeEstimate == 2)
    }

    @Test func linksAreReadAsObjectsAndAsPlainStrings() async throws {
        let tasks = try await tasksByName()
        #expect(tasks["Утро — душ 🚿"]?.previousTasks == ["Утро — зарядка 🤸"])
        #expect(tasks["Утро — завтрак 🥣"]?.previousTasks == ["Утро — душ 🚿"])
        #expect(tasks["Связь без скобок"]?.previousTasks == ["Найти отвёртку"])
        #expect(tasks["Связь на несуществующую"]?.previousTasks == ["Несуществующая задача"])
        let notes = try #require(tasks["Записать итоги разговора"])
        #expect(notes.previousEvent == EventLink(eventIdentifier: "fixture-event", title: "Call with dad",
                                                 start: TestCalendar.date("2026-10-21", "19:00")))
        #expect(notes.nextEvent == nil)
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
        var expected = TaskNote(name: "Длинная заметка с незнакомыми ключами",
                                relativePath: "TaskNotes/Tasks/Длинная заметка с незнакомыми ключами.md", status: .thisWeek)
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
        "Ждать ответа от арендодателя", "Забрать посылку на почте", "Записать идеи", "Записать итоги разговора",
        "Купить батарейки 🔋", "Купить молоко", "Медитация 🧘", "Найти отвёртку", "Неизвестное правило", "Обновить резюме",
        "Оплатить интернет", "Повесить зеркало", "Подготовить вопросы папе", "Позвонить в банк", "Полить цветы 🌱",
        "Помыть окна", "Посмотреть сериал 🍿", "Разобрать почту", "Распечатать вопросы", "Связь без скобок",
        "Связь на несуществующую", "Сдать отчёт", "Собрать шкаф", "Старая сделанная задача", "Стирка 🧺",
        "Сходить к стоматологу", "Утро — душ 🚿", "Утро — завтрак 🥣", "Утро — зарядка 🤸", "Цикл А", "Цикл Б",
    ]

    /// File systems may return names decomposed (NFD); names and links must come out composed (NFC),
    /// byte-for-byte as Obsidian writes them.
    @Test func namesAndLinksAreComposedUnicode() async throws {
        let tasks = try await scannedTasks()
        for task in tasks {
            #expect(Array(task.name.unicodeScalars) == Array(task.name.precomposedStringWithCanonicalMapping.unicodeScalars))
            for link in task.previousTasks {
                #expect(Array(link.unicodeScalars) == Array(link.precomposedStringWithCanonicalMapping.unicodeScalars))
            }
        }
        #expect(WikiLink.make("Найти отвёртку".decomposedStringWithCanonicalMapping).utf8.count
                == WikiLink.make("Найти отвёртку").utf8.count)
    }

    private func scannedTasks() async throws -> [TaskNote] {
        try await VaultSandbox.make().scan().tasks
    }

    private func tasksByName() async throws -> [String: TaskNote] {
        Dictionary(try await scannedTasks().map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func scanned(_ name: String) async throws -> TaskNote {
        try #require(try await tasksByName()[name])
    }

    /// Compares every field; the fixture timestamps are `YYYY-MM-DDT09:12:44.123+02:00`.
    private func expectSame(_ task: TaskNote, _ expected: TaskNote, created: String, modified: String,
                            sourceLocation: SourceLocation = #_sourceLocation) throws {
        let stamp = { (day: String) in TestCalendar.date(day, "09:12").addingTimeInterval(44.123) }
        let createdDate = try #require(task.dateCreated, sourceLocation: sourceLocation)
        let modifiedDate = try #require(task.dateModified, sourceLocation: sourceLocation)
        #expect(abs(createdDate.timeIntervalSince(stamp(created))) < 0.001, sourceLocation: sourceLocation)
        #expect(abs(modifiedDate.timeIntervalSince(stamp(modified))) < 0.001, sourceLocation: sourceLocation)
        var comparable = expected
        comparable.dateCreated = task.dateCreated
        comparable.dateModified = task.dateModified
        #expect(task == comparable, sourceLocation: sourceLocation)
    }
}
