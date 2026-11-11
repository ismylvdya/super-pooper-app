import Foundation
import Testing
@testable import SuperPooperApp

/// A task in Soon or Someday with a date of its own comes into the day when that date comes, as one in Next actions does;
/// until then it stays where it is, out of the pool and the review.
@Suite("A date in Soon or Someday")
struct DatedLevelTests {
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

    @Test func aDateThatHasComeBringsTheTaskIntoTheDay() async throws {
        let file = folder.appendingPathComponent(format.folder).appendingPathComponent(format.file)
        try """
        \(format.formatMarker)
        ## Next actions
        ## Soon
        - [ ] Dentist 📅 \(today.isoString)
        - [ ] Later 📅 \(today.adding(days: 3).isoString)
        ## Someday
        - [ ] Paint 📅 \(today.adding(days: -1).isoString)
        - [ ] Ideas
        """.write(to: file, atomically: true, encoding: .utf8)
        let tasks = try await store().load().tasks
        let plan = DayScenario(tasks: tasks).build(at: TestCalendar.context(TestCalendar.wednesday, "08:00"))
        #expect(plan.dayNames == ["Dentist", "Paint"] as Set)
        #expect(tasks.first { $0.name == "Later" }?.status == .halfYear)
        #expect(tasks.first { $0.name == "Ideas" }?.status == .someday)
    }
}
