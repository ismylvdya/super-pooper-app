import Foundation
import Testing
@testable import SuperPooperApp

/// The one file of tasks and the habits' JSON files, written and read back in a folder of their own.
@Suite("Task file store")
struct TaskFileStoreTests {
    private let folder: URL
    private let format = TestConfig.decode(TaskFileFormat.self, TaskFileFormat.fileName)
    private let today = LocalDate("2026-10-21")

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent(format.folder), withIntermediateDirectories: true)
    }

    private func store(today day: LocalDate? = nil) -> TaskFileStore {
        let day = day ?? today
        let fileSystem = CoordinatedFileSystem()
        let backups = BackupService(directory: folder.appendingPathComponent("Backups"), keepCount: 2, fileSystem: fileSystem,
                                    clock: { Date() }, calendar: FixedCalendar(current: TestCalendar.calendar))
        let counter = Counter()
        return TaskFileStore(location: FixedVaultLocation(url: folder), fileSystem: fileSystem, ubiquity: FakeUbiquityService(), format: format,
                             obsidian: TestConfig.mapping.obsidian, backups: backups, rules: TestConfig.rules.vault,
                             vaultSettings: { TestConfig.defaults.vault }, today: { day },
                             lookMemory: JSONDayLookMemory(store: JSONFileStore(directory: folder.appendingPathComponent("Memory"))),
                             makeID: { counter.next() })
    }

    private var file: URL { folder.appendingPathComponent(format.folder).appendingPathComponent(format.file) }
    private func text() throws -> String { try String(contentsOf: file, encoding: .utf8) }

    private func write(_ text: String) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: file, atomically: true, encoding: .utf8)
    }

    private func draft(_ changes: [TaskEdit] = []) -> NoteDraft { NoteDraft(status: .thisWeek, changes: changes) }

    @Test func aLineRoundTripsWithEveryField() {
        let line = "- [/] Call the doctor: urgent 📅 2026-11-04 ⏰ 14:00 🌐 Asia/Tokyo ⏳ 60 🔥 ❤️ ➕ 2026-11-01 🆔 a1"
        let entry = TaskEntry(line: line, format: format)
        #expect(entry?.name == "Call the doctor: urgent" && entry?.box == .started && entry?.isHigh == true && entry?.feel == .pleasant)
        #expect(entry?.date == LocalDate("2026-11-04") && entry?.time == LocalTime("14:00") && entry?.zone == "Asia/Tokyo" && entry?.estimate == 60)
        #expect(entry?.line(format: format) == line)
    }

    @Test func aMarkerInsideANameStaysInTheName() {
        #expect(TaskEntry(line: "- [ ] 🔥 fire drill 🆔 a1", format: format)?.name == "🔥 fire drill")
        #expect(TaskEntry(line: "just text", format: format) == nil)
    }

    @Test func theFileKeepsWhatIsNotItsOwnAndTheSubtasksAndTexts() {
        let text = """
        intro line

        ## Now
        ### Morning
        - [ ] Parent 🆔 p
            first line

            second line
            - [ ] Child 🆔 c
        ## My own
        anything at all
        - [ ] not a task of ours

        """
        let document = TaskDocument(text: text, format: format)
        let parent = document.entry(id: "p")
        #expect(document.prelude == ["intro line"])
        #expect(parent?.note == ["first line", "", "second line"] && parent?.children.map(\.name) == ["Child"])
        #expect(document.sections.first { $0.title == "My own" }?.other.contains("- [ ] not a task of ours") == true)
        let again = TaskDocument(text: document.text(format: format), format: format)
        #expect(again == document)
    }

    @Test func aNewTaskGoesToNowOrSoonByItsDate() async throws {
        let store = store()
        let now = try await store.create(draft(), named: "Today's")
        let later = try await store.create(draft([.due(TaskDue(day: LocalDate("2026-10-25")))]), named: "Later")
        #expect(now.status == .thisWeek && later.status == .thisWeek)
        let document = TaskDocument(text: try text(), format: format)
        #expect(document.sections.first { $0.kind == .now }?.groups[0].entries.map(\.name) == ["Today's"])
        #expect(document.sections.first { $0.kind == .soon }?.groups[0].entries.map(\.name) == ["Later"])
    }

    @Test func aTaskMovesBetweenSectionsByStatusWithItsTextAndSubtask() async throws {
        let store = store()
        var parent = try await store.create(NoteDraft(status: .thisWeek), named: "Parent")
        _ = try await store.setText("words", of: parent)
        _ = try await store.create(NoteDraft.subtask(of: "Parent"), named: "Child")
        parent = try await store.apply([.status(.someday)], to: parent).task
        #expect(parent.status == .someday)
        let loaded = try await store.load().tasks
        #expect(loaded.first { $0.name == "Child" }?.projects == ["Parent"])
        #expect(loaded.first { $0.name == "Child" }?.status == .someday, "a line goes with its parent")
        #expect(try await store.text(of: parent) == "words")
    }

    @Test func aDayLaterAPassedDateComesUpToTodayWithItsTime() async throws {
        let first = store()
        _ = try await first.create(draft([.due(TaskDue(day: LocalDate("2026-10-22"), time: LocalTime("14:00")))]), named: "Dentist")
        let later = store(today: LocalDate("2026-10-24"))
        let task = try await later.load().tasks.first
        #expect(task?.due == TaskDue(day: LocalDate("2026-10-24"), time: LocalTime("14:00")))
        #expect(TaskDocument(text: try text(), format: format).sections.first { $0.kind == .now }?.groups[0].entries.first?.name == "Dentist")
    }

    @Test func doneGoesToTheTopOfDoneAndBack() async throws {
        let store = store()
        let task = try await store.create(draft(), named: "Milk")
        let done = try await store.apply([.complete(on: today)], to: task).task
        #expect(done.status == .done)
        let filed = try await store.fileAway(done)
        #expect(try await store.load().tasks.isEmpty)
        #expect(try await store.filedTasks().map(\.name) == ["Milk"])
        let back = try await store.unfile(filed)
        #expect(back.status == .thisWeek && back.completedDate == nil)
        #expect(try await store.load().tasks.map(\.name) == ["Milk"])
    }

    @Test func aHabitIsAJSONFileAndItsDaysAreLinesInDone() async throws {
        let store = store()
        let rule = RecurrenceDraft(start: today).rule
        let habit = try await store.create(NoteDraft(status: .habit, changes: [.recurrence(rule), .timeOfDay(.morning), .reminderTimes([LocalTime("09:00")])]), named: "Run")
        #expect(habit.isHabit)
        let marked = try await store.apply([.mark(.twice, on: today)], to: habit).task
        #expect(marked.marks[today] == .twice)
        let lines = TaskDocument(text: try text(), format: format).sections.first { $0.kind == .done }?.groups[0].entries ?? []
        #expect(lines.count == 2 && lines.allSatisfy { $0.id == habit.id.value && $0.completed == today && $0.box == .done })
        var loaded = try await store.load().tasks
        #expect(loaded.first?.marks[today] == .twice && loaded.first?.habit.timeOfDay == .morning && loaded.first?.recurrence == rule)
        _ = try await store.apply([.mark(.partial, on: today)], to: marked)
        loaded = try await store.load().tasks
        #expect(loaded.first?.marks[today] == .partial)
        _ = try await store.apply([.mark(nil, on: today)], to: marked)
        loaded = try await store.load().tasks
        #expect(loaded.first?.marks[today] == nil)
        #expect(try await store.filedTasks().isEmpty, "a habit's lines are not done tasks")
    }

    @Test func aRenameKeepsTheHabitsDaysAndSubtasks() async throws {
        let store = store()
        let parent = try await store.create(NoteDraft(status: .thisWeek), named: "Old")
        _ = try await store.create(NoteDraft.subtask(of: "Old"), named: "Child")
        _ = try await store.rename(parent, to: "New", dependents: [])
        #expect(try await store.load().tasks.first { $0.name == "Child" }?.projects == ["New"])
        await #expect(throws: TaskStoreError.nameTaken("Child")) { try await store.rename(parent, to: "Child", dependents: []) }
    }

    @Test func theTrashHoldsATaskAndAHabitUntilRestored() async throws {
        let store = store()
        let task = try await store.create(draft(), named: "Milk")
        let habit = try await store.create(NoteDraft(status: .habit), named: "Run")
        let trashedTask = try await store.delete(task)
        let trashedHabit = try await store.delete(habit)
        #expect(try await store.load().tasks.isEmpty)
        #expect(Set(try await store.notes().map(\.name)) == ["Milk", "Run"])
        #expect(try await store.restore(try #require(trashedTask)) == "Milk")
        #expect(try await store.restore(try #require(trashedHabit)) == "Run")
        #expect(Set(try await store.load().tasks.map(\.name)) == ["Milk", "Run"])
        #expect(try await store.notes().isEmpty)
    }

    @Test func aTickOnAHabitsLineInObsidianIsItsMark() async throws {
        let store = store()
        let habit = try await store.create(NoteDraft(status: .habit), named: "Run")
        await store.mirror(DayMirror(sections: [.init(title: "Morning", names: ["Run"])], timed: [:], keptOut: []))
        #expect(try text().contains("### Morning\n- [ ] Run 🆔 \(habit.id.value)"))
        try write(try text().replacingOccurrences(of: "- [ ] Run", with: "- [x] Run"))
        let loaded = try await store.load().tasks
        #expect(loaded.first?.marks[today] == .done)
    }

    @Test func theMirrorPutsTheDaysSectionsInTheFileAndEmptyOnesGo() async throws {
        let store = store()
        _ = try await store.create(draft(), named: "A")
        _ = try await store.create(draft(), named: "B")
        _ = try await store.create(draft(), named: "C")
        await store.mirror(DayMirror(sections: [.init(title: "Evening", names: ["B", "A"]), .init(title: "Empty", names: [])], timed: [:], keptOut: ["C"]))
        let document = TaskDocument(text: try text(), format: format)
        let now = try #require(document.sections.first { $0.kind == .now })
        #expect(now.groups.compactMap(\.title) == ["Evening"])
        #expect(now.groups.last?.entries.map(\.name) == ["B", "A"])
        #expect(document.sections.first { $0.kind == .soon }?.groups[0].entries.map(\.name) == ["C"])
        #expect(Set(try await store.load().tasks.map(\.name)) == ["A", "B", "C"], "all still there")
    }

    @Test func aLineTypedByHandGetsItsIDAndAStrangeSectionStays() async throws {
        try write("## Now\n- [ ] By hand\n\n## Ideas\nfree text\n")
        let store = store()
        let tasks = try await store.load().tasks
        #expect(tasks.first?.name == "By hand" && tasks.first?.id != .unsaved)
        #expect(try text().contains("## Ideas\nfree text"))
    }

    @Test func importTakesTasksHabitsAndDoneOnceEach() async throws {
        let store = store()
        var habit = TaskItem(id: .unsaved, name: "Run", status: .habit)
        habit.marks = [today: .done]
        let items = [ImportedItem(item: TaskItem(id: .unsaved, name: "Open", status: .someday), text: "words", isFiled: false),
                     ImportedItem(item: TaskItem(id: .unsaved, name: "Finished", status: .done), text: "", isFiled: true),
                     ImportedItem(item: habit, text: "", isFiled: false)]
        #expect(try await store.importItems(items) == 3)
        #expect(try await store.importItems(items) == 0, "a name it has stays")
        let loaded = try await store.load().tasks
        #expect(loaded.first { $0.name == "Open" }?.status == .someday)
        #expect(loaded.first { $0.name == "Run" }?.marks[today] == .done)
        #expect(try await store.filedTasks().map(\.name) == ["Finished"])
    }

    /// Lines moved by hand between Now's sections, or kept out to Soon, come back as news once; the app's own look does not.
    @Test func aLookChangedInTheFileComesBackAndTheAppsOwnDoesNot() async throws {
        let store = store()
        _ = try await store.create(draft(), named: "A")
        _ = try await store.create(draft(), named: "B")
        _ = try await store.create(draft(), named: "C")
        await store.mirror(DayMirror(sections: [.init(title: "Morning", names: ["A", "B"]), .init(title: "Evening", names: ["C"])], timed: [:], keptOut: []))
        #expect(await store.changedLook() == nil, "what the app wrote itself")
        _ = try await store.create(draft(), named: "New")
        #expect(await store.changedLook() == nil, "a new line is no change of the look")

        var document = TaskDocument(text: try text(), format: format)
        let now = try #require(document.sections.firstIndex { $0.kind == .now })
        let morning = try #require(document.sections[now].groups.firstIndex { $0.title == "Morning" })
        let evening = try #require(document.sections[now].groups.firstIndex { $0.title == "Evening" })
        let moved = document.sections[now].groups[morning].entries.removeFirst()
        document.sections[now].groups[evening].entries.append(moved)
        document.sections[now].groups[evening].title = "Night"
        try write(document.text(format: format))

        let look = try #require(await store.changedLook())
        #expect(look.sections == [.init(title: "Morning", names: ["B"]), .init(title: "Night", names: ["C", "A"])])
        await store.mirror(DayMirror(sections: [.init(title: "Lost", names: ["A"])], timed: [:], keptOut: []))
        #expect(try text().contains("### Night"), "not written over until it is taken in")
        await store.accept(look)
        #expect(await store.changedLook() == nil)
    }

    /// The next day the file's look is yesterday's: no news, the day's sections start anew.
    @Test func yesterdaysLookIsNoNews() async throws {
        let first = store()
        _ = try await first.create(draft(), named: "A")
        await first.mirror(DayMirror(sections: [.init(title: "Morning", names: ["A"])], timed: [:], keptOut: []))
        try write(try text().replacingOccurrences(of: "### Morning", with: "### Renamed"))
        #expect(await first.changedLook() != nil)
        #expect(await store(today: LocalDate("2026-10-22")).changedLook() == nil)
    }

    /// The old TaskNotes folder, or any other chosen by mistake, stays untouched: a problem, no file made.
    @Test func aFolderWithoutTheTasksFolderIsNotWrittenTo() async throws {
        try FileManager.default.removeItem(at: folder.appendingPathComponent(format.folder))
        let store = store()
        let result = try await store.load()
        #expect(result.fileProblems == [.tasksFolderMissing(format.folder)])
        await #expect(throws: TaskStoreError.folderMissing(format.folder)) { try await store.create(draft(), named: "A") }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
    }

    @Test func namesWithAMarkerAreRefused() {
        #expect(store().nameProblem(in: "Run 🔥") != nil)
        #expect(store().nameProblem(in: "Встреча: Анна") == nil, "only the markers and blanks are the file's business")
        #expect(store().nameProblem(in: " ") == .empty)
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> String {
        lock.withLock {
            value += 1
            return "id\(value)"
        }
    }
}
