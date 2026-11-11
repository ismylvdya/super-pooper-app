import Foundation
import Testing
@testable import SuperPooperApp

/// An older file's own lists become projects once: a parent line of the list's title marked 🗂️ in Someday, its lines
/// under it; the file as it was is kept in a backup.
@Suite("Own lists become projects")
struct ListsToProjectsTests {
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

    @Test func aListBecomesAProjectWithItsTasksUnderIt() async throws {
        let file = folder.appendingPathComponent(format.folder).appendingPathComponent(format.file)
        try """
        \(format.formatMarker)
        ## Next actions
        ## Soon
        ## Someday
        - [ ] Ideas
        ## Lists
        - [ ] Loose
        ### Trip to Masha
        - [ ] Book a train
        - [ ] Buy a gift
        """.write(to: file, atomically: true, encoding: .utf8)
        let tasks = try await store().load().tasks
        let project = try #require(tasks.first { $0.name == "Trip to Masha" })
        #expect(project.showsAsProject && project.status == .someday)
        #expect(tasks.filter { $0.projects == ["Trip to Masha"] }.map(\.name).sorted() == ["Book a train", "Buy a gift"])
        #expect(tasks.first { $0.name == "Loose" }?.status == .someday)
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(!text.contains("## Lists") && !text.contains("### "))
        #expect(text.contains("- [ ] Trip to Masha 🗂️\n    - [ ] Book a train"))
        let backups = try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("Backups").path)
        #expect(!backups.isEmpty)
        #expect(ProjectList.projects(in: tasks).map(\.name) == ["Trip to Masha"])
        #expect(ProjectList.openCount(of: project, in: tasks) == 2)
    }

    @Test func aProjectIsNotInThePoolItself() {
        let project = makeTask("Job search") {
            $0.showsAsProject = true
            $0.due = TaskDue(day: LocalDate(TestCalendar.wednesday))
        }
        let step = makeTask("CV") {
            $0.projects = ["Job search"]
            $0.due = TaskDue(day: LocalDate(TestCalendar.wednesday))
        }
        let plan = DayScenario(tasks: [project, step]).build(at: TestCalendar.context(TestCalendar.wednesday, "08:00"))
        #expect(plan.poolNames == ["CV"])
        #expect(plan.pool.first?.project == "Job search")
    }

    @Test func theMarkerIsInTheLine() {
        let line = "- [ ] Job search 🗂️"
        let entry = TaskEntry(line: line, format: format)
        #expect(entry?.showsAsProject == true && entry?.name == "Job search")
        #expect(entry?.line(format: format) == line)
    }
}
