import Foundation
import Testing
@testable import SuperPooperApp

/// Regressions from the code review: concurrent edits, odd files and name collisions.
@Suite("Review regressions")
struct ReviewRegressionTests {
    /// The phone's copy is stale (scanned before the Mac marked the 18th); marking the 21st must
    /// keep the 18th that is in the file now.
    @Test func markingAppliesToTheLatestFileNotTheStaleCopy() async throws {
        let note = try await SandboxNote("Медитация 🧘")
        let original = try note.text()
        #expect(!original.contains("2026-10-18"))
        let onMac = try original.replacingOnce("complete_instances:\n", with: "complete_instances:\n  - 2026-10-18\n")
        try note.sandbox.write(onMac, to: note.task.name)
        try await note.mark(.done)
        let instances = note.task.completeInstances.map(\.isoString)
        #expect(instances.contains("2026-10-18"))
        #expect(instances.contains("2026-10-21"))
    }

    @Test func entriesTheAppCannotReadSurviveAMark() async throws {
        let sandbox = try VaultSandbox.make()
        let text = "---\ntags:\n  - 🔫делишка\nstatus: half_year\nrecurrence: DTSTART:20260901;FREQ=DAILY\n"
            + "complete_instances:\n  - not-a-date\n  - 2026-10-19\ndate_modified: 2026-10-20T09:12:44.123+02:00\n---\n"
        try sandbox.write(text, to: "Странная привычка")
        let note = try await SandboxNote("Странная привычка", sandbox: sandbox)
        try await note.mark(.done)
        #expect(try note.text().contains("  - not-a-date\n  - 2026-10-19\n  - 2026-10-21\n"))
    }

    @Test func editingTheBodyOfANoteWithoutTrailingNewlineKeepsItValid() async throws {
        let sandbox = try VaultSandbox.make()
        try sandbox.write("---\ntags:\n  - 🔫делишка\nstatus: this_week\n---", to: "Без перевода строки")
        let note = try await SandboxNote("Без перевода строки", sandbox: sandbox)
        _ = try await note.repository.setBody("Hello", of: note.task)
        let text = try note.text()
        #expect(text.hasSuffix("\n---\nHello"))
        #expect(throws: Never.self) { try FrontmatterDocument(text: text) }
    }

    @Test func renameSurvivesADependentThatVanished() async throws {
        let sandbox = try VaultSandbox.make()
        let repository = sandbox.repository()
        let tasks = try await repository.scan().tasks
        let screwdriver = try #require(tasks.first { $0.name == "Найти отвёртку" })
        var ghost = try #require(tasks.first { $0.name == "Собрать шкаф" })
        ghost.relativePath = "TaskNotes/Tasks/Нет такого файла.md"
        let renamed = try await repository.rename(screwdriver, to: "Найти отвёртку 2", dependents: [ghost])
        #expect(renamed.name == "Найти отвёртку 2")
        #expect(sandbox.exists("Найти отвёртку 2"))
    }

    @Test func anEvictedFileStillTakesItsName() async throws {
        let sandbox = try VaultSandbox.make()
        try "".write(to: sandbox.tasksFolder.appendingPathComponent(".Занято облаком.md.icloud"), atomically: true, encoding: .utf8)
        let repository = sandbox.repository()
        let batteries = try #require(try await repository.scan().tasks.first { $0.name == "Купить батарейки 🔋" })
        await #expect(throws: TaskRepositoryError.nameTaken("Занято облаком")) {
            _ = try await repository.rename(batteries, to: "Занято облаком", dependents: [])
        }
    }
}

/// Times between midnight and the day boundary belong to the end of the logical day.
@Suite("Day boundary")
struct DayBoundaryTests {
    @Test func aHabitAfterMidnightIsPlacedAtTheEndOfToday() throws {
        let night = makeHabit("Night pills", time: "00:30")
        let plan = DayScenario(tasks: [night]).build(at: TestCalendar.context("2026-10-21", "22:00"))
        let slot = try #require(plan.slot("Night pills"))
        #expect(slot.start == TestCalendar.date("2026-10-22", "00:30"))
    }

    @Test func aTaskDueAfterMidnightBelongsToThePreviousLogicalDay() throws {
        let late = makeTask("Late call") { $0.due = TaskDue("2026-10-22T01:00") }
        let plan = DayScenario(tasks: [late]).build(at: TestCalendar.context("2026-10-21", "22:00"))
        #expect(plan.slot("Late call")?.start == TestCalendar.date("2026-10-22", "01:00"))
        #expect(TestCalendar.context().logicalDay(of: TaskDue("2026-10-22T01:00")) == LocalDate("2026-10-21"))
    }

    @Test func aNightHabitNotificationBelongsToItsLogicalDay() throws {
        let night = makeHabit("Night pills", time: "00:30")
        let planned = NotificationPlanner(horizonDays: 1, limit: 10)
            .plan(tasks: [night], reminders: [], skipped: [], context: TestCalendar.context("2026-10-21", "22:00"))
        let first = try #require(planned.first)
        #expect(first.day == LocalDate("2026-10-21"))
        #expect(first.fireDate == TestCalendar.date("2026-10-22", "00:30"))
    }
}
