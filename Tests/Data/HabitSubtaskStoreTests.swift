import Foundation
import Testing
@testable import SuperPooperApp

/// A habit's subtasks are tasks standing under its one open line, which the app writes anew: they go along with it.
@Suite("Habit subtasks in the file")
struct HabitSubtaskStoreTests {
    private let folder: URL
    private let format = TestConfig.decode(TaskFileFormat.self, TaskFileFormat.fileName)
    private let today = LocalDate("2026-10-21")

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent(format.folder), withIntermediateDirectories: true)
    }

    private func store() -> TaskFileStore {
        let fileSystem = CoordinatedFileSystem()
        let backups = BackupService(directory: folder.appendingPathComponent("Backups"), keepCount: 2, fileSystem: fileSystem,
                                    clock: { Date() }, calendar: FixedCalendar(current: TestCalendar.calendar))
        return TaskFileStore(location: FixedVaultLocation(url: folder), fileSystem: fileSystem, ubiquity: FakeUbiquityService(), format: format,
                             obsidian: TestConfig.obsidian, backups: backups, rules: TestConfig.rules.vault,
                             vaultSettings: { TestConfig.defaults.vault }, today: { [today] in today },
                             lookMemory: JSONDayLookMemory(store: JSONFileStore(directory: folder.appendingPathComponent("Memory"))))
    }

    private func text() throws -> String {
        try String(contentsOf: folder.appendingPathComponent(format.folder).appendingPathComponent(format.file), encoding: .utf8)
    }

    private func habit(_ store: TaskFileStore, named name: String) async throws -> TaskItem {
        try await store.create(NoteDraft(status: .habit, changes: [.recurrence(RecurrenceDraft(start: today).rule)]), named: name)
    }

    /// Made under a habit, a subtask is a task under its line; the mirror writes the line anew and the subtask stays under
    /// it, and goes along to the habit's next day once the habit is done.
    @Test func aSubtaskGoesAlongWithItsHabitsLine() async throws {
        let store = store()
        let run = try await habit(store, named: "Run")
        _ = try await store.load()
        await store.accept(try #require(await store.currentLook()))
        _ = await store.mirror(DayMirror(sections: [.init(title: "Day", names: ["Run"])], timed: [:]))
        let shoes = try await store.create(.subtask(of: run), named: "Shoes")
        #expect(!shoes.isHabit && shoes.projects == ["Run"] && shoes.due == TaskDue(day: today))
        _ = await store.mirror(DayMirror(sections: [.init(title: "Day", names: ["Run", "Shoes"])], timed: [:]))
        #expect(try text().contains("- [ ] Run 📅 \(today.isoString) 🔁 every-day 🆔 \(run.id.value)\n    - [ ] Shoes\n"))
        _ = try await store.apply([.mark(.done, on: today)], to: run)
        _ = await store.mirror(DayMirror(sections: [], timed: [:]))
        let tomorrow = today.adding(days: 1).isoString
        #expect(try text().contains("- [ ] Run 📅 \(tomorrow) 🔁 every-day 🆔 \(run.id.value)\n    - [ ] Shoes\n"))
        #expect(try await store.load().tasks.first { $0.name == "Shoes" }?.due == TaskDue(day: today.adding(days: 1)))
    }

    /// An older file's subtask of a habit was a habit itself: it becomes a task once, beside its habit naming it, and the
    /// mirror puts it under the habit's line.
    @Test func anOlderSubhabitBecomesATask() async throws {
        let store = store()
        let run = try await habit(store, named: "Run")
        var old = HabitFile(id: "sub1", item: TaskItem(id: TaskID("sub1"), name: "Stretch", status: .habit), parent: run.id.value, note: "slowly")
        old.timeEstimate = 10
        let habitsFolder = folder.appendingPathComponent(format.folder).appendingPathComponent(format.habitsFolder)
        try old.text().write(to: habitsFolder.appendingPathComponent("sub1.json"), atomically: true, encoding: .utf8)
        let tasks = try await store.load().tasks
        let stretch = try #require(tasks.first { $0.name == "Stretch" })
        #expect(!stretch.isHabit && stretch.projects == ["Run"] && stretch.timeEstimate == 10)
        #expect(try await store.text(of: stretch) == "slowly")
        #expect(!FileManager.default.fileExists(atPath: habitsFolder.appendingPathComponent("sub1.json").path))
        await store.accept(try #require(await store.currentLook()))
        _ = await store.mirror(DayMirror(sections: [.init(title: "Day", names: ["Run"])], timed: [:]))
        let written = try text()
        #expect(written.contains("🆔 \(run.id.value)\n    - [ ] Stretch ⏳ 10 🏊\n        slowly\n"), Comment(rawValue: written))
    }

    /// Deleted with its habit, a subtask goes to the trash too, not lost with the habit's line.
    @Test func aSubtaskOutlivesItsHabitsLineGoing() async throws {
        let store = store()
        let run = try await habit(store, named: "Run")
        _ = try await store.load()
        await store.accept(try #require(await store.currentLook()))
        _ = await store.mirror(DayMirror(sections: [.init(title: "Day", names: ["Run"])], timed: [:]))
        let shoes = try await store.create(.subtask(of: run), named: "Shoes")
        _ = try await store.delete(run)
        #expect(try text().contains("- [ ] Shoes 🔼"))
        _ = try await store.delete(shoes)
        #expect(Set(try await store.notes().map(\.name)) == ["Run", "Shoes"])
    }

    /// The pool's order is the order of the lines (D-180): the mirror writes a habit's line anew in its place, and every
    /// item knows its line's place.
    @Test func aHabitsLineKeepsItsPlaceAmongTheLines() async throws {
        let store = store()
        let run = try await habit(store, named: "Run")
        _ = try await store.load()
        await store.accept(try #require(await store.currentLook()))
        _ = await store.mirror(DayMirror(sections: [.init(title: "Day", names: ["Run"])], timed: [:]))
        let text = try self.text().replacingOccurrences(of: "## Next actions\n", with: "## Next actions\n- [ ] First 🏊\n")
        try text.write(to: folder.appendingPathComponent(format.folder).appendingPathComponent(format.file), atomically: true, encoding: .utf8)
        _ = await store.mirror(DayMirror(sections: [.init(title: "Day", names: ["Run"])], timed: [:]))
        let lines = try self.text().components(separatedBy: "\n")
        let first = try #require(lines.firstIndex(of: "- [ ] First 🏊"))
        let habit = try #require(lines.firstIndex { $0.contains("🆔 \(run.id.value)") })
        #expect(first < habit, "the habit's line stays after the line put before it")
        let tasks = try await store.load().tasks
        let order = { (name: String) in tasks.first { $0.name == name }?.storeOrder ?? -1 }
        #expect(order("First") < order("Run"))
    }
}
