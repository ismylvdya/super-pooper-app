import Foundation
import Testing
@testable import SuperPooper

/// Reading single notes from text: the forms TaskNotes and people actually write, defaults for missing
/// fields and problems (never failures) for unreadable ones.
@Suite("Task note reading")
struct TaskNoteReaderTests {
    private let reader = TaskNoteReader(mapping: TestConfig.mapping, taskTag: TestConfig.defaults.vault.taskTag,
                                        calendar: TestCalendar.calendar)

    @Test(arguments: [
        "tags:\n  - 🔫делишка",
        "tags: 🔫делишка",
        "tags: [дом, \"#🔫делишка\"]",
        "tags:\n  - 🔫делишка/дом",
    ])
    func theTaskTagIsRecognisedInEveryForm(tags: String) throws {
        #expect(reader.isTask(try FrontmatterDocument(text: "---\n\(tags)\nstatus: this_week\n---\n")))
    }

    @Test(arguments: ["tags:\n  - 🔫делишкаx", "tags: [дом]", "status: this_week"])
    func otherTagsAreNotTasks(tags: String) throws {
        #expect(!reader.isTask(try FrontmatterDocument(text: "---\n\(tags)\n---\n")))
    }

    @Test func linksAreReadInEveryFormTheyAreWritten() throws {
        let task = try read("""
        previous_task:
          - uid: "[[Объект]]"
            reltype: FINISHTOSTART
          - "[[В кавычках]]"
          - [[Без кавычек]]
          - "[[Папка/Путь]]"
          - "[[С псевдонимом|псевдоним]]"
          - Просто имя
        """)
        #expect(task.previousTasks == ["Объект", "В кавычках", "Без кавычек", "Путь", "С псевдонимом", "Просто имя"])
        #expect(task.problems.isEmpty)
        #expect(try read("previous_task: \"[[Одна строка]]\"").previousTasks == ["Одна строка"])
    }

    @Test func missingFieldsGetDefaults() throws {
        let task = try read("")
        #expect(task.status == .other(""))
        #expect(!task.isHighPriority && task.due == nil && task.timeEstimate == nil)
        #expect(!task.needEnergy && task.pleasant == nil && !task.isHabit)
        #expect(task.previousTasks.isEmpty && task.completeInstances.isEmpty && task.problems.isEmpty)
    }

    @Test func statusesAndPrioritiesComeFromTheMapping() throws {
        #expect(try read("status: half_year\npriority: high").status == .halfYear)
        #expect(try read("status: half_year\npriority: high").isHighPriority)
        #expect(try !read("priority: none").isHighPriority)
        #expect(try read("status: in_progress").status == .other("in_progress"))
    }

    @Test func anEventTitleMayContainTheSeparator() throws {
        let task = try read("next_event: \"EK-1|Call | dad|2026-10-21T19:00:00+02:00\"")
        #expect(task.nextEvent == EventLink(eventIdentifier: "EK-1", title: "Call | dad", start: TestCalendar.date("2026-10-21", "19:00")))
    }

    @Test func unreadableValuesBecomeProblemsAndTheRestIsStillRead() throws {
        let task = try read("""
        status: this_week
        due: tomorrow
        time_estimate: lots
        need_energy: maybe
        previous_event: "not a link"
        complete_instances:
          - 2026-10-20
          - 2026-13-01
        pleasant: false
        """)
        #expect(task.status == .thisWeek && task.pleasant == false)
        #expect(task.due == nil && task.timeEstimate == nil && !task.needEnergy && task.previousEvent == nil)
        #expect(task.completeInstances == [LocalDate("2026-10-20")])
        #expect(Set(task.problems) == [
            .invalidField(key: "due", value: "tomorrow"),
            .invalidField(key: "time_estimate", value: "lots"),
            .invalidField(key: "need_energy", value: "maybe"),
            .invalidField(key: "previous_event", value: "not a link"),
            .invalidField(key: "complete_instances", value: "2026-13-01"),
        ])
    }

    @Test func dueKeepsAnOptionalTime() throws {
        #expect(try read("due: 2026-10-23").due == TaskDue("2026-10-23"))
        #expect(try read("due: 2026-10-23T16:00").due == TaskDue("2026-10-23T16:00"))
        #expect(try read("due: 2026-10-23T16:00:00").due == TaskDue("2026-10-23T16:00"))
    }

    private func read(_ frontmatter: String) throws -> TaskNote {
        let text = "---\ntags:\n  - 🔫делишка\n\(frontmatter)\n---\n"
        return reader.task(from: try FrontmatterDocument(text: text), name: "Задача", relativePath: "TaskNotes/Tasks/Задача.md")
    }
}

@Suite("Habit fields")
struct HabitFieldTests {
    private let mapping = TestConfig.mapping
    private let reader = TaskNoteReader(mapping: TestConfig.mapping, taskTag: TestConfig.defaults.vault.taskTag,
                                        calendar: TestCalendar.calendar)

    private func document(_ frontmatter: String) throws -> FrontmatterDocument {
        try FrontmatterDocument(text: "---\ntags:\n  - 🔫делишка\n\(frontmatter)\n---\n")
    }

    @Test func statusHabitAndSeveralReminderTimesAreRead() throws {
        let task = reader.task(from: try document("status: habit\nreminder_times:\n  - \"21:00\"\n  - \"09:00\""),
                               name: "Pills", relativePath: "TaskNotes/Tasks/Pills.md")
        #expect(task.status == .habit && task.isHabit)
        #expect(task.reminderTimes == [LocalTime(hour: 9, minute: 0)!, LocalTime(hour: 21, minute: 0)!])
        #expect(task.problems.isEmpty)
    }

    @Test func aBadReminderTimeBecomesAProblem() throws {
        let task = reader.task(from: try document("reminder_times: [\"9am\"]"), name: "Pills", relativePath: "x.md")
        #expect(task.problems == [.invalidField(key: "reminder_times", value: "9am")])
    }

    @Test func recurrenceAndRemindersAreWrittenAndRemoved() throws {
        var doc = try document("status: this_week")
        let writer = TaskNoteWriter(mapping: mapping, timeZone: TestCalendar.timeZone)
        writer.apply([.status(.habit), .recurrence("DTSTART:20261023T000000Z;FREQ=DAILY"),
                      .reminderTimes([LocalTime(hour: 21, minute: 0)!, LocalTime(hour: 9, minute: 0)!])],
                     to: &doc, now: TestCalendar.date("2026-10-23", "09:00"))
        let task = reader.task(from: doc, name: "Pills", relativePath: "x.md")
        #expect(task.status == .habit)
        #expect(task.recurrenceRaw == "DTSTART:20261023T000000Z;FREQ=DAILY")
        #expect(task.reminderTimes.map(\.string) == ["09:00", "21:00"])

        writer.apply([.status(.thisWeek), .recurrence(nil), .reminderTimes([])], to: &doc, now: TestCalendar.date("2026-10-23", "10:00"))
        let back = reader.task(from: doc, name: "Pills", relativePath: "x.md")
        #expect(!back.isHabit && back.reminderTimes.isEmpty)
    }
}
