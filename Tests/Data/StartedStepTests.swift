import Foundation
import Testing
@testable import SuperPooperApp

/// `[/]` only shows that a task is started: everywhere else it is an open task, the first step of one shown one at a
/// time too.
@Suite("Started is open")
struct StartedStepTests {
    private let folder: URL
    private let format = TestConfig.decode(TaskFileFormat.self, TaskFileFormat.fileName)
    private let today = LocalDate(TestCalendar.wednesday)

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent(format.folder), withIntermediateDirectories: true)
    }

    private func store() -> TaskFileStore {
        let fileSystem = CoordinatedFileSystem()
        let backups = BackupService(directory: folder.appendingPathComponent("Backups"), keepCount: 2, fileSystem: fileSystem,
                                    clock: { Date() }, calendar: FixedCalendar(current: TestCalendar.calendar))
        let counter = Counter()
        let day = today
        return TaskFileStore(location: FixedVaultLocation(url: folder), fileSystem: fileSystem, ubiquity: FakeUbiquityService(), format: format,
                             obsidian: TestConfig.obsidian, backups: backups, rules: TestConfig.rules.vault,
                             vaultSettings: { TestConfig.defaults.vault }, today: { day },
                             lookMemory: JSONDayLookMemory(store: JSONFileStore(directory: folder.appendingPathComponent("Memory"))),
                             makeID: { counter.next() })
    }

    @Test func aStartedFirstStepStaysInThePoolAsOpen() async throws {
        let store = store()
        let trip = try await store.create(NoteDraft(status: .thisWeek, changes: [.due(TaskDue(day: today)), .stepsOneByOne(true)]), named: "Trip")
        _ = try await store.create(NoteDraft.subtask(of: "Trip"), named: "Pack")
        _ = try await store.create(NoteDraft.subtask(of: "Trip"), named: "Go")
        let pack = try #require(try await store.load().tasks.first { $0.name == "Pack" })
        _ = try await store.apply([.started(true)], to: pack)
        let tasks = try await store.load().tasks
        #expect(tasks.first { $0.name == "Pack" }?.status == .thisWeek)
        #expect(tasks.first { $0.name == "Pack" }?.isStarted == true)
        let plan = DayScenario(tasks: tasks).build(at: TestCalendar.context(TestCalendar.wednesday, "08:00"))
        #expect(plan.poolNames == ["Pack"])
        #expect(plan.item(named: "Pack")?.isDone == false)
        _ = trip
    }

    /// The day written to the file with the step in one of the pool's sections: the step stays under its task.
    @Test func aStepInAPoolSectionStaysUnderItsTask() async throws {
        let store = store()
        _ = try await store.create(NoteDraft(status: .thisWeek, changes: [.due(TaskDue(day: today)), .stepsOneByOne(true)]), named: "Trip")
        _ = try await store.create(NoteDraft.subtask(of: "Trip"), named: "Pack")
        let pack = try #require(try await store.load().tasks.first { $0.name == "Pack" })
        _ = try await store.apply([.started(true)], to: pack)
        await store.mirror(DayMirror(sections: [.init(title: "Day", names: ["Pack", "Trip"])], timed: [:]))
        let tasks = try await store.load().tasks
        let step = try #require(tasks.first { $0.name == "Pack" })
        #expect(step.projects == ["Trip"])
        #expect(step.due?.day == today)
        #expect(step.isStarted && step.status == .thisWeek)
    }
}
