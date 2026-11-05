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
        let line = "- [/] Call the doctor: urgent 📅 2026-11-04 ⏰ 14:00 🌐 Asia/Tokyo ⏳ 60 ⚠️ ❤️ 🆔 a1"
        let entry = TaskEntry(line: line, format: format)
        #expect(entry?.name == "Call the doctor: urgent" && entry?.box == .started && entry?.isHigh == true && entry?.feel == .pleasant)
        #expect(entry?.date == LocalDate("2026-11-04") && entry?.time == LocalTime("14:00") && entry?.zone == "Asia/Tokyo" && entry?.estimate == 60)
        #expect(entry?.line(format: format) == line)
    }

    @Test func aMarkerInsideANameStaysInTheName() {
        #expect(TaskEntry(line: "- [ ] ⚠️ fire drill 🆔 a1", format: format)?.name == "⚠️ fire drill")
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

    @Test func aDayLaterAPassedDateComesUpToTodayWithoutItsTime() async throws {
        let first = store()
        _ = try await first.create(draft([.due(TaskDue(day: LocalDate("2026-10-22"), time: LocalTime("14:00")))]), named: "Dentist")
        let later = store(today: LocalDate("2026-10-24"))
        let task = try await later.load().tasks.first
        #expect(task?.due == TaskDue(day: LocalDate("2026-10-24")), "the time passed with its day: the task waits in the pool")
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
        #expect(try text().contains("### Morning\n- [ ] Run 📅 \(today.isoString) 🆔 \(habit.id.value)"))
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
        #expect(store().nameProblem(in: "Run ⚠️") != nil)
        #expect(store().nameProblem(in: "Встреча: Анна") == nil, "only the markers and blanks are the file's business")
        #expect(store().nameProblem(in: " ") == .empty)
    }

    // MARK: - Names

    @Test func aNameInDoneOrTheTrashIsFreeForANewTask() async throws {
        let store = store()
        let done = try await store.create(draft(), named: "Haircut")
        _ = try await store.fileAway(done)
        let again = try await store.create(draft(), named: "Haircut")
        #expect(again.name == "Haircut")
        _ = try await store.delete(again)
        let third = try await store.create(draft(), named: "Haircut")
        #expect(third.name == "Haircut")
        let written = try text()
        #expect(written.contains("- [x] Haircut ✅ \(today.isoString)\n"))
        #expect(written.contains("- [ ] Haircut\n"), "a plain task keeps no id in the file: \(third.name)")
        #expect(try await store.load().tasks.map(\.name) == ["Haircut"])
    }

    // MARK: - The file's words

    @Test func olderTitlesAndFieldsTurnIntoTodaysOnTheFirstRead() async throws {
        try write("## Inbox\n- [ ] Idea ➕ 2026-11-01 🆔 i1\n## Now\n- [ ] Milk ➕ 2026-11-01 🆔 m1\n## Soon\n- [ ] Later 🆔 l1\n")
        let tasks = try await store().load().tasks
        #expect(Set(tasks.map(\.name)) == ["Idea", "Milk", "Later"])
        let written = try text()
        #expect(!written.contains("Inbox") && !written.contains("## Now") && !written.contains("➕"))
        #expect(written.contains("## Today\n- [ ] Milk\n"))
        #expect(written.contains("## Soon\n- [ ] Later\n- [ ] Idea\n"))
        let today = try #require(written.range(of: "## Today")), soon = try #require(written.range(of: "## Soon"))
        #expect(today.lowerBound < soon.lowerBound, "the sections stay in their order")
    }

    @Test func theOlderHighPriorityMarkTurnsIntoTheWarningSign() async throws {
        try write("## Today\n- [ ] Call 🔥 🆔 c1\n")
        let task = try #require(try await store().load().tasks.first)
        #expect(task.isHighPriority)
        #expect(try text().contains("- [ ] Call ⚠️\n"))
    }

    @Test func twoFiledTasksOfOneNameAreToldApartAndOldIDsLeave() async throws {
        let store = store()
        try write("## Today\n- [ ] Parent 🆔 p1\n## Soon\n- [ ] Child 🔼 p1 🆔 c1\n")
        let tasks = try await store.load().tasks
        #expect(tasks.first { $0.name == "Child" }?.projects == ["Parent"], "the parent is found by its old id")
        #expect(try text().contains("- [ ] Child 🔼 Parent\n"))
        let again = try await store.load().tasks
        #expect(again.first { $0.name == "Child" }?.projects == ["Parent"], "and by its name from then on")
        let first = try await store.create(draft(), named: "Haircut")
        _ = try await store.fileAway(first)
        let second = try await store.create(draft(), named: "Haircut")
        _ = try await store.fileAway(second)
        let filed = try await store.filedTasks()
        #expect(Set(filed.map(\.id)).count == 2)
        _ = try await store.unfile(try #require(filed.first))
        #expect(try await store.filedTasks().count == 1)
    }

    @Test func openInObsidianPointsAtABlockOnTheOneLine() async throws {
        let store = store()
        let first = try await store.create(draft(), named: "One")
        let second = try await store.create(draft(), named: "Two")
        let url = await store.externalURL(for: first)
        #expect(url?.absoluteString.contains("Tasks.md%23") == true || url?.query?.contains("Tasks.md#") == true)
        #expect(try text().contains("- [ ] One ^open\n"))
        _ = await store.externalURL(for: second)
        #expect(try text().contains("- [ ] One\n- [ ] Two ^open\n"))
    }

    @Test func theOpenMarkOutlivesLaterEdits() async throws {
        let store = store()
        let first = try await store.create(draft(), named: "One")
        let second = try await store.create(draft(), named: "Two")
        _ = await store.externalURL(for: first)
        _ = try await store.apply([.highPriority(true)], to: second)
        _ = try await store.load()
        #expect(try text().contains("- [ ] One ^open\n"))
        _ = try await store.apply([.highPriority(true)], to: first)
        #expect(try text().contains("^open"))
    }

    @Test func aRenamedHabitKeepsItsOldNameInDone() async throws {
        let store = store()
        let habit = try await store.create(NoteDraft(status: .habit), named: "Run")
        _ = try await store.apply([.mark(.done, on: today)], to: habit)
        _ = try await store.rename(habit, to: "Jog", dependents: [])
        #expect(try text().contains("- [x] Run ✅ \(today.isoString) 🆔 \(habit.id.value)"))
        #expect(try await store.load().tasks.first?.marks[today] == .done)
    }

    // MARK: - Repeats and what was missed

    private func weekly(_ days: [Weekday], from start: LocalDate) -> RecurrenceRule {
        RecurrenceRule(startDate: start, startTime: nil, frequency: .weekly, interval: 1, byDay: days.map { RecurrenceWeekday(weekday: $0, ordinal: nil) },
                       byMonthDay: [], byMonth: [], count: nil, untilDate: nil, untilTime: nil, weekStart: .monday)
    }

    private func habitDraft(_ rule: RecurrenceRule, times: [LocalTime] = []) -> NoteDraft {
        NoteDraft(status: .habit, changes: [.recurrence(rule), .reminderTimes(times)])
    }

    private func line(of name: String) throws -> String? {
        try text().components(separatedBy: "\n").first { $0.hasPrefix("- [ ] \(name) ") }
    }

    /// Everything before the line's own section heading ends there: which section a line stands in.
    private func section(of name: String) throws -> String? {
        var current: String?
        for line in try text().components(separatedBy: "\n") {
            if line.hasPrefix("## ") { current = String(line.dropFirst(3)) }
            if line.hasPrefix("- [ ] \(name) ") { return current }
        }
        return nil
    }

    @Test func aHabitNotOfTodayWaitsInSoonOnItsNearestDayWithItsRuleAndTime() async throws {
        let store = store()
        let other = today.adding(days: 2).weekday
        _ = try await store.create(habitDraft(weekly([other], from: today), times: [LocalTime(hour: 9, minute: 30)!]), named: "Gym")
        await store.mirror(DayMirror(sections: [], timed: [:], keptOut: []))
        let line = try #require(try line(of: "Gym"))
        #expect(try section(of: "Gym") == "Soon")
        #expect(line.contains("📅 \(today.adding(days: 2).isoString) ⏰ 09:30"))
        #expect(line.contains("🔁 every-"))
    }

    @Test func aHabitClosedTodayGoesToDoneAndItsNextDayToSoon() async throws {
        let store = store()
        let daily = RecurrenceRule(startDate: today, startTime: nil, frequency: .daily, interval: 1, byDay: [], byMonthDay: [], byMonth: [],
                                   count: nil, untilDate: nil, untilTime: nil, weekStart: .monday)
        let habit = try await store.create(habitDraft(daily), named: "Read")
        _ = try await store.apply([.mark(.done, on: today)], to: habit)
        await store.mirror(DayMirror(sections: [.init(title: "Day", names: ["Read"])], timed: [:], keptOut: []))
        #expect(try section(of: "Read") == "Soon")
        #expect(try line(of: "Read")?.contains("📅 \(today.adding(days: 1).isoString)") == true)
        #expect(try text().contains("- [x] Read ✅ \(today.isoString)"))
    }

    @Test func aTaskMissedAtItsTimeIsCarriedWithoutItAndMarked() async throws {
        let yesterday = today.adding(days: -1)
        try write("## Today\n- [ ] Call 📅 \(yesterday.isoString) ⏰ 14:00 🆔 c1\n- [ ] Plain 📅 \(yesterday.isoString) 🆔 p1\n")
        let tasks = try await store().load().tasks
        let call = try #require(tasks.first { $0.name == "Call" })
        let plain = try #require(tasks.first { $0.name == "Plain" })
        #expect(call.isOverdue && call.due == TaskDue(day: today))
        #expect(!plain.isOverdue && plain.due == TaskDue(day: today))
        #expect(try text().contains("- [ ] Call 📅 \(today.isoString) 🕰️\n"))
    }

    @Test func aMissedHabitWithoutADayNowIsCarriedOverdueWithNoTimes() async throws {
        let store = store()
        let yesterday = today.adding(days: -1)
        let rule = weekly([yesterday.weekday], from: yesterday)
        let habit = try await store.create(habitDraft(rule, times: [LocalTime(hour: 8, minute: 0)!]), named: "Gym")
        try write("## Today\n- [ ] Gym 📅 \(yesterday.isoString) ⏰ 08:00 🔁 every-x 🆔 \(habit.id.value)\n")
        let loaded = try #require(try await store.load().tasks.first)
        #expect(loaded.isOverdue && loaded.habitTimes.isEmpty)
        #expect(try line(of: "Gym")?.contains("📅 \(today.isoString) 🔁 every-x 🕰️") == true)
        #expect(!loaded.reminderTimes.isEmpty, "its settings stay")
    }

    @Test func aMissedHabitWithADayNowJustStartsAnew() async throws {
        let store = store()
        let yesterday = today.adding(days: -1)
        let daily = RecurrenceRule(startDate: yesterday, startTime: nil, frequency: .daily, interval: 1, byDay: [], byMonthDay: [], byMonth: [],
                                   count: nil, untilDate: nil, untilTime: nil, weekStart: .monday)
        let habit = try await store.create(habitDraft(daily), named: "Read")
        try write("## Today\n- [ ] Read 📅 \(yesterday.isoString) ⏰ 08:00 🆔 \(habit.id.value)\n")
        let loaded = try #require(try await store.load().tasks.first)
        #expect(!loaded.isOverdue)
        #expect(try line(of: "Read") == nil, "the mirror writes its new line")
    }

    @Test(arguments: [
        (RecurrenceFrequency.daily, 1, [String](), [Int](), "every-day"),
        (.daily, 6, [], [], "every-6-days"),
        (.monthly, 1, [], [-1], "every-last-day-of-month"),
        (.monthly, 1, [], [15], "every-15-of-month")
    ])
    func aRuleSaysItselfInOneWord(frequency: RecurrenceFrequency, interval: Int, days: [String], monthDays: [Int], expected: String) {
        let rule = RecurrenceRule(startDate: nil, startTime: nil, frequency: frequency, interval: interval, byDay: [], byMonthDay: monthDays,
                                  byMonth: [], count: nil, untilDate: nil, untilTime: nil, weekStart: .monday)
        #expect(RepeatTag.text(of: rule) == expected)
    }

    @Test func weekdaysAndLastWeekdaySayThemselves() {
        let week = weekly([.saturday, .monday], from: today)
        #expect(RepeatTag.text(of: week) == "every-mon-sat")
        let last = RecurrenceRule(startDate: nil, startTime: nil, frequency: .monthly, interval: 1, byDay: [RecurrenceWeekday(weekday: .saturday, ordinal: -1)],
                                  byMonthDay: [], byMonth: [], count: nil, untilDate: nil, untilTime: nil, weekStart: .monday)
        #expect(RepeatTag.text(of: last) == "every-last-sat-of-month")
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

/// Alarms: in a task's line, and in a habit's file for each of its times.
struct AlarmFormatTests {
    private let format = TestConfig.decode(TaskFileFormat.self, "task-file.json")

    @Test func aLineKeepsItsAlarmAndSound() throws {
        var entry = TaskEntry(name: "Dentist")
        entry.alarm = "chime"
        let line = entry.line(format: format)
        #expect(line.contains("🚨 chime"))
        #expect(TaskEntry(line: line, format: format)?.alarm == "chime")
    }

    @Test func theDefaultSoundIsAWordInTheLineAndNilInTheApp() throws {
        var entry = TaskEntry(name: "Dentist")
        var task = TaskItem(id: TaskID("1"), name: "Dentist", status: .thisWeek)
        task.alarms = [TimeAlarm()]
        entry.update(from: task, format: format)
        #expect(entry.alarm == format.alarmDefaultSound)
        #expect(entry.item(in: .now, parentName: nil, order: nil, format: format).alarms == [TimeAlarm()])
    }

}
