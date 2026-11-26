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
                             obsidian: TestConfig.obsidian, backups: backups, rules: TestConfig.rules.vault,
                             vaultSettings: { TestConfig.defaults.vault }, today: { day },
                             lookMemory: JSONDayLookMemory(store: JSONFileStore(directory: folder.appendingPathComponent("Memory"))),
                             makeID: { counter.next() })
    }

    private var file: URL { folder.appendingPathComponent(format.folder).appendingPathComponent(format.file) }
    /// The tasks file and, when there is one, Done's beside it.
    private func text() throws -> String {
        let done = file.deletingLastPathComponent().appendingPathComponent(format.doneFile)
        let finished = (try? String(contentsOf: done, encoding: .utf8)) ?? ""
        return try String(contentsOf: file, encoding: .utf8) + finished
    }

    private func write(_ text: String) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: file, atomically: true, encoding: .utf8)
    }

    private func draft(_ changes: [TaskEdit] = []) -> NoteDraft { NoteDraft(status: .thisWeek, changes: changes) }

    @Test func taskPlacementsRoundTripThroughMarkdown() async throws {
        let repository = store()
        let context = TestCalendar.context()
        let time = LocalTime("15:00")
        let moment = context.date(today, time)
        var task = try await repository.create(NoteDraft(status: .someday), named: "Placement")
        let edits = TaskPlacementMove.changes(for: task, to: .pool(today, sectionTag: "evening"),
                                              fromScheduled: false, context: context)
        task = try await repository.apply(edits, to: task).task
        #expect(try text().contains("Placement 🏊 in_today_pool 🏊 section_evening"))
        #expect(task.status == .thisWeek && task.isInTodayPool && task.poolSection == "evening")

        task = try await repository.apply(TaskPlacementMove.changes(for: task, to: .scheduled(moment),
                                                                   fromScheduled: false, context: context), to: task).task
        #expect(task.due == TaskDue(day: today, time: time) && !task.isInTodayPool && task.poolSection == nil)
        #expect(try text().contains("Placement \(format.markers.date) \(today) \(format.markers.time) 15:00"))

        let back = TaskPlacementMove.changes(for: task, to: .list(.halfYear), fromScheduled: true, context: context)
        task = try await repository.apply(back, to: task).task
        #expect(task.status == .halfYear && task.due == nil && !task.isInTodayPool && task.poolSection == nil)
        #expect(try await repository.load().tasks.first?.status == .halfYear)
    }

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

        ## Next actions
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
        let again = TaskDocument(text: (document.tasksText(format: format) + document.doneText(format: format)), format: format)
        #expect(again == document)
    }

    /// Every new task of this week stands in Next actions; one dated today is in today's pool.
    @Test func aNewTaskStandsInNextActionsAndTodaysInThePool() async throws {
        let store = store()
        let now = try await store.create(draft([.due(TaskDue(day: today))]), named: "Today's")
        let later = try await store.create(draft([.due(TaskDue(day: LocalDate("2026-10-25")))]), named: "Later")
        #expect(now.status == .thisWeek && later.status == .thisWeek && now.isInTodayPool && !later.isInTodayPool)
        let document = TaskDocument(text: try text(), format: format)
        #expect(document.sections.first { $0.kind == .soon }?.groups[0].entries.map(\.name) == ["Today's", "Later"])
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

    /// A passed date stays (a deadline): the line is marked overdue and in today's pool, and its time has gone with its day.
    @Test func aDayLaterAPassedDateStaysWithoutItsTime() async throws {
        let first = store()
        _ = try await first.create(draft([.due(TaskDue(day: LocalDate("2026-10-22"), time: LocalTime("14:00")))]), named: "Dentist")
        let later = store(today: LocalDate("2026-10-24"))
        let task = try #require(try await later.load().tasks.first)
        #expect(task.due == TaskDue(day: LocalDate("2026-10-22")) && task.isOverdue && task.isInTodayPool)
        #expect(TaskDocument(text: try text(), format: format).sections.first { $0.kind == .soon }?.groups[0].entries.first?.name == "Dentist")
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

    @Test func quantityAndPartialReplaceEachOtherWithoutChangingCompletionMarks() async throws {
        let store = store()
        let habit = try await store.create(NoteDraft(status: .habit), named: "Run")
        let marked = try await store.apply([.mark(.partial, on: today)], to: habit).task
        let tracking = HabitQuantity(maximum: 10, step: 1)
        let recording = try await store.apply([.habitQuantityTracking(tracking), .habitQuantity(.amount(1), on: today)], to: marked).task
        let loaded = try await store.load().tasks.first
        #expect(try text().contains("Run 🔢 1 ✅ \(today)"))
        #expect(loaded?.habit.quantityTracking == tracking && loaded?.quantityEntry(on: today) == .amount(1))
        #expect(loaded?.isDone(on: today) == true && loaded?.mark(on: today) == .partial)

        let marking = TaskMarking(today: today)
        let attempted = try await store.apply(marking.changes(marking: recording, as: .partial), to: recording).task
        #expect(try text().contains("- [/] Run 🔢 partial ✅ \(today)"))
        #expect(try !text().contains("Run 🔢 1 ✅ \(today)"))
        #expect(try await store.load().tasks.first?.quantityEntry(on: today) == .partial)
        #expect(!attempted.isDone(on: today) && !DayItem(habit: attempted, on: today).isFinished)

        let completed = try await store.apply([.habitQuantity(.amount(2), on: today)], to: attempted).task
        #expect(completed.quantityEntry(on: today) == .amount(2) && DayItem(habit: completed, on: today).isFinished)
        #expect(try !text().contains("Run 🔢 partial ✅ \(today)"))
        _ = try await store.apply(marking.changes(marking: completed, as: nil), to: completed)
        let cleared = try await store.load().tasks.first
        #expect(cleared?.quantityEntry(on: today) == nil && cleared?.isDone(on: today) == false)
        #expect(try !text().contains("Run 🔢 2 ✅ \(today)"))
        #expect(cleared?.mark(on: today) == .partial)
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
        await store.mirror(DayMirror(sections: [.init(title: "Morning", names: ["Run"])], timed: [:]))
        #expect(try text().contains("## Next actions\n- [ ] Run 📅 \(today.isoString) 🆔 \(habit.id.value)"))
        try write(try text().replacingOccurrences(of: "- [ ] Run", with: "- [x] Run"))
        let loaded = try await store.load().tasks
        #expect(loaded.first?.marks[today] == .done)
    }

    /// The mirror writes the habits' lines only: a task's line says itself where it stands, and stays where it is.
    @Test func theMirrorLeavesTheTasksAsTheyAre() async throws {
        let store = store()
        _ = try await store.create(draft(), named: "A")
        _ = try await store.create(draft(), named: "B")
        _ = try await store.create(draft(), named: "C")
        let before = try text()
        await store.mirror(DayMirror(sections: [.init(title: "Evening", names: ["B", "A"]), .init(title: "Empty", names: [])], timed: [:]))
        #expect(try text() == before)
        #expect(!before.contains("###") && !before.contains("## Today"))
    }

    @Test func aLineTypedByHandGetsItsIDAndAStrangeSectionStays() async throws {
        try write("## Now\n- [ ] By hand\n\n## Ideas\nfree text\n")
        let store = store()
        let tasks = try await store.load().tasks
        #expect(tasks.first?.name == "By hand" && tasks.first?.id != .unsaved)
        #expect(try text().contains("## Ideas\nfree text"))
    }

    /// A habit's line moved by hand to a later day (kept out of today) comes back as news once; the app's own look does not.
    @Test func aLookChangedInTheFileComesBackAndTheAppsOwnDoesNot() async throws {
        let store = store()
        _ = try await store.create(NoteDraft(status: .habit, changes: [.recurrence(RecurrenceDraft(start: today).rule)]), named: "Run")
        _ = try await store.load()
        await store.accept(try #require(await store.currentLook()))
        await store.mirror(DayMirror(sections: [.init(title: "Morning", names: ["Run"])], timed: [:]))
        #expect(await store.changedLook() == nil, "what the app wrote itself")
        let tomorrow = today.adding(days: 1).isoString
        try write(try text().replacingOccurrences(of: "Run 📅 \(today.isoString)", with: "Run 📅 \(tomorrow)"))
        let look = try #require(await store.changedLook())
        #expect(look.skipped == ["Run"])
        await store.mirror(DayMirror(sections: [.init(title: "Morning", names: ["Run"])], timed: [:]))
        #expect(try text().contains("Run 📅 \(tomorrow)"), "not written over until it is taken in")
        await store.accept(look)
        #expect(await store.changedLook() == nil)
    }

    /// The next day the file's look is yesterday's: no news.
    @Test func yesterdaysLookIsNoNews() async throws {
        let first = store()
        _ = try await first.create(NoteDraft(status: .habit, changes: [.recurrence(RecurrenceDraft(start: today).rule)]), named: "Run")
        _ = try await first.load()
        await first.accept(try #require(await first.currentLook()))
        await first.mirror(DayMirror(sections: [.init(title: "Morning", names: ["Run"])], timed: [:]))
        try write(try text().replacingOccurrences(of: "Run 📅 \(today.isoString)", with: "Run 📅 \(today.adding(days: 1).isoString)"))
        #expect(await first.changedLook() != nil)
        #expect(await store(today: LocalDate("2026-10-22")).changedLook() == nil)
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

    /// An older file's titles go by today's, its Now joins Next actions in today's pool, and fields no longer kept go.
    @Test func olderTitlesAndFieldsTurnIntoTodaysOnTheFirstRead() async throws {
        try write("## Inbox\n- [ ] Idea ➕ 2026-11-01 🆔 i1\n## Now\n- [ ] Milk ➕ 2026-11-01 🆔 m1\n## Soon\n- [ ] Later 🆔 l1\n")
        let tasks = try await store().load().tasks
        #expect(Set(tasks.map(\.name)) == ["Idea", "Milk", "Later"])
        let written = try text()
        #expect(!written.contains("Inbox") && !written.contains("## Now") && !written.contains("## Today") && !written.contains("➕"))
        #expect(written.contains("## Next actions\n- [ ] Later 🏊 in_today_pool\n- [ ] Idea 🏊 in_today_pool\n- [ ] Milk 🏊 in_today_pool\n"))
    }

    @Test func theOlderHighPriorityMarkTurnsIntoTheWarningSign() async throws {
        try write("## Soon\n- [ ] Call 🔥 🆔 c1\n")
        let task = try #require(try await store().load().tasks.first)
        #expect(task.isHighPriority)
        #expect(try text().contains("- [ ] Call ⚠️ 🏊 in_today_pool\n"))
    }

    @Test func twoFiledTasksOfOneNameAreToldApartAndOldIDsLeave() async throws {
        let store = store()
        try write("## Next actions\n- [ ] Parent 🆔 p1\n## Someday\n- [ ] Child 🔼 p1 🆔 c1\n")
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

    @Test func openObsidianNamesTheLineAndLeavesTheFileAsItIs() async throws {
        let store = store()
        _ = try await store.create(draft(), named: "One")
        let task = try await store.create(draft(), named: "Two")
        let before = try text()
        let url = try #require(await store.externalURL(for: task))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(url.host() == "superpooper-line")
        let line = try #require(items.first { $0.name == "line" }?.value.flatMap(Int.init))
        #expect(before.components(separatedBy: "\n")[line] == "- [ ] Two")
        #expect(items.first { $0.name == "name" }?.value == "Two")
        #expect(try text() == before)
    }

    @Test func aHabitOpensOnItsOpenLineNotItsDaysInDone() async throws {
        let store = store()
        let habit = try await store.create(NoteDraft(status: .habit), named: "Run")
        _ = try await store.apply([.mark(.done, on: today.adding(days: -1))], to: habit)
        await store.mirror(DayMirror(sections: [.init(title: "Morning", names: ["Run"])], timed: [:]))
        let url = try #require(await store.externalURL(for: habit))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let line = try #require(items.first { $0.name == "line" }?.value.flatMap(Int.init))
        #expect(try text().components(separatedBy: "\n")[line].hasPrefix("- [ ] Run"))
    }

    /// Skip today: the day's look has no line for the habit, so its one line takes the rule's next day and goes to Soon.
    @Test func aSkippedHabitsLineMovesToSoonOnItsNextDay() async throws {
        let store = store()
        let rule = RecurrenceDraft(start: today).rule
        let habit = try await store.create(NoteDraft(status: .habit, changes: [.recurrence(rule)]), named: "Run")
        await store.mirror(DayMirror(sections: [.init(title: "Morning", names: ["Run"])], timed: [:]))
        #expect(try text().contains("## Next actions\n- [ ] Run 📅 \(today.isoString)"))
        await store.mirror(DayMirror(sections: [], timed: [:]))
        let lines = try text().components(separatedBy: "\n")
        let soon = try #require(lines.firstIndex(of: "## Next actions"))
        let line = try #require(lines.firstIndex { $0.hasPrefix("- [ ] Run") && $0.contains(habit.id.value) })
        #expect(line > soon)
        #expect(lines[line].contains("📅 \(today.adding(days: 1).isoString)"))
    }

    /// A habit with no line yet (a twice-a-day one written anew in the morning) takes its place in the day's order, its
    /// routine's: right after the line before it, not on top of the list.
    @Test func aNewHabitLineGoesAfterTheLineBeforeItNotOnTop() async throws {
        let store = store()
        let rule = RecurrenceDraft(start: today).rule
        for name in ["Water", "Shower", "Pushups"] {
            _ = try await store.create(NoteDraft(status: .habit, changes: [.recurrence(rule)]), named: name)
        }
        await store.mirror(DayMirror(sections: [.init(title: "Morning", names: ["Water", "Shower"])], timed: [:]))
        await store.mirror(DayMirror(sections: [.init(title: "Morning", names: ["Water", "Shower", "Pushups"])], timed: [:]))
        let lines = try text().components(separatedBy: "\n")
        let place = { (name: String) in try #require(lines.firstIndex { $0.hasPrefix("- [ ] \(name)") }) }
        #expect(try place("Water") < place("Shower"))
        #expect(try place("Shower") < place("Pushups"), "after the routine's line before it")
    }

    /// Skipped with no day of its own tomorrow: tomorrow's pool, no time, marked overdue.
    @Test func aSkippedHabitWithNoDayTomorrowStandsThereOverdue() async throws {
        let store = store()
        var weekly = RecurrenceDraft(start: today)
        weekly.frequency = .weekly
        let rule = weekly.rule
        _ = try await store.create(NoteDraft(status: .habit, changes: [.recurrence(rule)]), named: "Bins")
        await store.mirror(DayMirror(sections: [], timed: [:], skipped: ["Bins"]))
        let line = try #require(try text().components(separatedBy: "\n").first { $0.hasPrefix("- [ ] Bins") })
        #expect(line.contains("📅 \(today.adding(days: 1).isoString)") && line.contains("🕰️"))
    }

    /// An undated line in an older file's Today is in today's pool; a new undated task waits in Next actions, out of it.
    @Test func anOlderTodaysLineIsInThePoolAndANewOneIsNot() async throws {
        try write("%% day \(today.isoString) %%\n## Today\n- [ ] Old\n")
        let store = store()
        _ = try await store.load()
        _ = try await store.create(draft(), named: "New")
        let lines = try text().components(separatedBy: "\n")
        #expect(lines.contains("- [ ] Old 🏊 in_today_pool") && lines.contains("- [ ] New"))
    }

    /// An archived line stays in the archive, whatever date and time it has.
    @Test func theArchiveKeepsItsLinesWhateverTheirDates() async throws {
        let line = "- [ ] Old 📅 \(today.adding(days: -3).isoString) ⏰ 10:00"
        try write("## Next actions\n## Archive\n\(line)\n")
        _ = try await store().load()
        let lines = try text().components(separatedBy: "\n")
        let written = try #require(lines.firstIndex(of: line.replacingOccurrences(of: "⏰", with: "🕐")))
        #expect(written > lines.firstIndex(of: "## Archive")!)
    }

    /// Done's lines live in a file of their own, an older file's move there.
    @Test func doneMovesToItsOwnFile() async throws {
        try write("## Next actions\n## Done\n- [x] Old ✅ 2026-01-01\n")
        _ = try await store().load()
        let tasks = try String(contentsOf: file, encoding: .utf8)
        let done = try String(contentsOf: file.deletingLastPathComponent().appendingPathComponent(format.doneFile), encoding: .utf8)
        #expect(!tasks.contains("Old") && !tasks.contains("## Done"))
        #expect(done.contains("## Done\n- [x] Old ✅ 2026-01-01"))
    }

    /// A new day takes off every pool mark and puts it on what is due: what is undated in Next actions, and what is dated
    /// today or earlier in any list. A passed date stays (a deadline) and is marked overdue, its time gone; a later date,
    /// and an undated task of a later list, stay out. Sections that do not last go.
    @Test func aNewDayPutsWhatIsDueInThePool() async throws {
        let later = today.adding(days: 3).isoString
        let past = today.adding(days: -2).isoString
        try write("%% day \(today.adding(days: -1).isoString) %%\n\n## Next actions\n- [ ] Idle 🏊 section_after_work\n- [ ] Later 📅 \(later) 🏊 in_today_pool\n"
                  + "- [ ] Early 🏊 section_morning\n## Soon\n- [ ] Far 🏊 in_today_pool\n## Someday\n- [ ] Past 📅 \(past) ⏰ 10:00\n")
        let tasks = try await store().load().tasks
        let pooled = Set(tasks.filter(\.isInTodayPool).map(\.name))
        #expect(pooled == ["Idle", "Early", "Past"])
        let lines = try text().components(separatedBy: "\n")
        #expect(lines.contains("- [ ] Idle 🏊 in_today_pool") && lines.contains("- [ ] Early 🏊 in_today_pool 🏊 section_morning"))
        #expect(lines.contains("- [ ] Later 📅 \(later)") && lines.contains("- [ ] Far"))
        #expect(lines.contains("- [ ] Past 📅 \(past) 🕰️ 🏊 in_today_pool"))
        #expect(lines.first == "%% format 2 %%" && lines.contains("%% day \(today.isoString) %%"))
    }

    /// The pool is Next actions': a task of Soon or Someday dated today moves there with the day's turn, a subtask naming
    /// its parent.
    @Test func aDueTaskOfALaterListMovesToNextActions() async throws {
        try write("%% day \(today.adding(days: -1).isoString) %%\n\n## Next actions\n## Soon\n- [ ] Trip\n    - [ ] Visa 📅 \(today.isoString)\n"
                  + "## Someday\n- [ ] Paint 📅 \(today.isoString)\n")
        let tasks = try await store().load().tasks
        #expect(tasks.filter(\.isInTodayPool).allSatisfy { $0.status == .thisWeek })
        #expect(Set(tasks.filter(\.isInTodayPool).map(\.name)) == ["Visa", "Paint"])
        let file = try text()
        #expect(file.contains("## Next actions\n- [ ] Visa 📅 \(today.isoString) 🔼 Trip 🏊 in_today_pool\n- [ ] Paint 📅 \(today.isoString) 🏊 in_today_pool\n"))
    }

    /// Kept out of tomorrow in yesterday's review: the day's turn leaves it out of the pool and takes the mark away.
    @Test func aTaskKeptOutOfTomorrowStaysOut() async throws {
        try write("%% day \(today.adding(days: -1).isoString) %%\n\n## Next actions\n- [ ] Idle 🏊 not_tomorrow_pool\n- [ ] Other\n")
        let tasks = try await store().load().tasks
        #expect(tasks.first { $0.name == "Idle" }?.isInTodayPool == false && tasks.first { $0.name == "Other" }?.isInTodayPool == true)
        #expect(try text().contains("- [ ] Idle\n- [ ] Other 🏊 in_today_pool\n"))
    }

    /// A task added during the day waits for the next morning.
    @Test func theSameDayLeavesNextActionsAsItIs() async throws {
        try write("%% day \(today.isoString) %%\n\n## Next actions\n- [ ] New\n")
        let tasks = try await store().load().tasks
        #expect(tasks.first?.due == nil && tasks.first?.isInTodayPool == false)
    }

    /// Not today during the day: out of the pool, its date and list kept, until the next morning brings it back.
    @Test func notTodayTakesTheMarkOnly() async throws {
        try write("%% day \(today.isoString) %%\n\n## Next actions\n## Soon\n- [ ] Call 📅 \(today.isoString) 🏊 in_today_pool\n")
        let store = store()
        let task = try #require(try await store.load().tasks.first)
        #expect(task.isInTodayPool && task.status == .halfYear)
        _ = try await store.apply([.inTodayPool(false)], to: task)
        let reloaded = try #require(try await store.load().tasks.first)
        #expect(reloaded.due == TaskDue(day: today) && !reloaded.isInTodayPool && reloaded.status == .halfYear)
        #expect(try text().contains("## Soon\n- [ ] Call 📅 \(today.isoString)\n"))
    }

    /// A date set to today or earlier brings a task into the pool; a later one takes it out.
    @Test func aDateDecidesThePoolWhenItIsSet() async throws {
        try write("%% day \(today.isoString) %%\n\n## Next actions\n- [ ] Call\n")
        let store = store()
        let task = try #require(try await store.load().tasks.first)
        let dated = try await store.apply([.due(TaskDue(day: today))], to: task).task
        #expect(dated.isInTodayPool)
        let later = try await store.apply([.due(TaskDue(day: today.adding(days: 1)))], to: dated).task
        #expect(!later.isInTodayPool)
    }

    /// An older file's Today joins Next actions once, with a backup: its open lines are in the pool, each group's title is
    /// its section's tag (Day, the rest, has none), and its headings make no projects. The date the morning gave a line
    /// with no time goes (the mark says it now); a time keeps its date, and so does a later date.
    @Test func anOlderFilesTodayBecomesTags() async throws {
        try write("%% format 2 %%\n%% day \(today.isoString) %%\n\n## Today\n- [ ] Timed 📅 \(today.isoString) 🕐 10:00\n### Morning\n- [ ] Stretch 📅 \(today.isoString)\n"
                  + "### Day\n- [ ] Mail\n    - [ ] Reply\n### After work\n- [ ] Cook 📅 \(today.adding(days: 2).isoString)\n## Next actions\n- [ ] Waiting\n## Soon\n")
        let tasks = try await store().load().tasks
        #expect(Set(tasks.filter(\.isInTodayPool).map(\.name)) == ["Timed", "Stretch", "Mail", "Reply", "Cook"])
        #expect(tasks.first { $0.name == "Stretch" }?.poolSection == "morning")
        #expect(tasks.first { $0.name == "Mail" }?.poolSection == nil && tasks.first { $0.name == "Cook" }?.poolSection == "after_work")
        #expect(tasks.allSatisfy { !$0.showsAsProject })
        let file = try text()
        #expect(!file.contains("## Today") && !file.contains("###"))
        #expect(file.contains("## Next actions\n- [ ] Waiting\n- [ ] Timed 📅 \(today.isoString) 🕐 10:00 🏊 in_today_pool\n- [ ] Stretch 🏊 in_today_pool 🏊 section_morning\n"))
        #expect(file.contains("- [ ] Cook 📅 \(today.adding(days: 2).isoString) 🏊 in_today_pool 🏊 section_after_work\n"))
    }

    /// The pool's older hashtags are read as before and written as the swimmer's marks with the first read, the file kept
    /// as it was in a backup first (D-187).
    @Test func olderPoolHashtagsBecomeTheSwimmersMarks() async throws {
        try write("%% format 2 %%\n%% day \(today.isoString) %%\n\n## Next actions\n- [ ] Stretch #in_today_pool #section_morning\n"
                  + "- [ ] Mail #not_tomorrow\n## Soon\n")
        let tasks = try await store().load().tasks
        #expect(tasks.first { $0.name == "Stretch" }.map { $0.isInTodayPool && $0.poolSection == "morning" } == true)
        #expect(tasks.first { $0.name == "Mail" }?.isNotTomorrow == true)
        let file = try text()
        #expect(!file.contains("#in_today_pool") && !file.contains("#section_") && !file.contains("#not_tomorrow"))
        #expect(file.contains("- [ ] Stretch 🏊 in_today_pool 🏊 section_morning\n") && file.contains("- [ ] Mail 🏊 not_tomorrow_pool"))
        let backups = try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("Backups").path)
        #expect(backups.contains { $0.contains("poolmarks") })
    }

    /// The mirror says where each habit's line stands, and the item read back knows it: open today it stands on today,
    /// closed it goes on to its next day.
    @Test func aHabitKnowsTheDayOfItsLine() async throws {
        let store = store()
        var water = try await store.create(habitDraft(RecurrenceDraft(start: today).rule), named: "Water")
        let open = await store.mirror(DayMirror(sections: [DayMirror.Section(title: "Day", names: ["Water"])], timed: [:], skipped: []))
        #expect(open?[water.id]?.day == today)
        water = try await store.apply([.mark(.done, on: today)], to: water).task
        let closed = await store.mirror(DayMirror(sections: [], timed: [:], skipped: []))
        #expect(closed?[water.id]?.day == today.adding(days: 1))
        #expect(try await store.load().tasks.first { $0.name == "Water" }?.nextLine?.day == today.adding(days: 1))
    }

    // MARK: - Subtasks go with their parent

    private func parentAndStore(_ lines: String) async throws -> (TaskFileStore, [TaskItem]) {
        try write("%% day \(today.isoString) %%\n\n\(lines)")
        let store = store()
        return (store, try await store.load().tasks)
    }

    /// A subtask added under a task of today's pool stands under it, on its day, and is not in Next actions.
    @Test func aNewSubtaskOfATodayTaskStandsUnderIt() async throws {
        let (store, tasks) = try await parentAndStore("## Next actions\n- [ ] Pack 📅 \(today.isoString) 🏊 in_today_pool\n## Soon\n")
        let child = try await store.create(.subtask(of: try #require(tasks.first)), named: "Earrings")
        #expect(child.due == TaskDue(day: today) && child.isInTodayPool && child.projects == ["Pack"])
        #expect(try text().replacingOccurrences(of: "\n\n", with: "\n").contains("- [ ] Pack 📅 \(today.isoString) 🏊 in_today_pool\n    - [ ] Earrings 🏊 in_today_pool\n## Soon"))
    }

    /// In a later day's or another list's parent the same: the subtask does not fall out to Next actions.
    @Test func aNewSubtaskGoesToItsParentsList() async throws {
        let later = today.adding(days: 3)
        let (store, tasks) = try await parentAndStore("## Today\n## Next actions\n- [ ] Trip 📅 \(later.isoString)\n## Soon\n- [ ] Far\n## Someday\n")
        let trip = try await store.create(.subtask(of: try #require(tasks.first { $0.name == "Trip" })), named: "Tickets")
        let far = try await store.create(.subtask(of: try #require(tasks.first { $0.name == "Far" })), named: "Plan")
        #expect(trip.due == TaskDue(day: later) && far.status == .halfYear && far.due == nil)
        #expect(try text().replacingOccurrences(of: "\n\n", with: "\n").contains("- [ ] Trip 📅 \(later.isoString)\n    - [ ] Tickets\n## Soon\n- [ ] Far\n    - [ ] Plan\n"))
    }

    /// The parent moves, and whatever has no date of its own moves with it and is told so; a time of its own stays.
    @Test func subtasksFollowTheirParentsDate() async throws {
        let (store, tasks) = try await parentAndStore("## Today\n- [ ] Pack 📅 \(today.isoString)\n    - [ ] Earrings\n    - [ ] Call 📅 \(today.isoString) 🕐 10:00\n## Next actions\n")
        let result = try await store.apply([.due(nil)], to: try #require(tasks.first { $0.name == "Pack" }))
        let earrings = try #require(result.subtasks.first { $0.name == "Earrings" })
        #expect(earrings.due == nil)
        #expect(result.subtasks.first { $0.name == "Call" }?.due == TaskDue(day: today, time: LocalTime(hour: 10, minute: 0)))
    }

    /// Not today on a subtask: it leaves the pool and stays under its parent.
    @Test func aSubtaskTakenOutOfTheDayStaysUnderItsParent() async throws {
        let (store, tasks) = try await parentAndStore("## Next actions\n- [ ] Pack 📅 \(today.isoString) 🏊 in_today_pool\n    - [ ] Earrings 🏊 in_today_pool\n")
        let out = try await store.apply([.inTodayPool(false)], to: try #require(tasks.first { $0.name == "Earrings" }))
        #expect(!out.task.isInTodayPool && out.task.projects == ["Pack"])
        #expect(try text().contains("- [ ] Pack 📅 \(today.isoString) 🏊 in_today_pool\n    - [ ] Earrings\n"))
    }

    /// An edit of a following subtask does not write its parent's day into it; the next morning takes a stray line back.
    @Test func aFollowingSubtaskKeepsNoDateOfItsOwn() async throws {
        let (store, tasks) = try await parentAndStore("## Next actions\n- [ ] Pack 📅 \(today.isoString) 🏊 in_today_pool\n    - [ ] Earrings 🏊 in_today_pool\n")
        _ = try await store.apply([.highPriority(true)], to: try #require(tasks.first { $0.name == "Earrings" }))
        #expect(try text().contains("    - [ ] Earrings ⚠️ 🏊 in_today_pool\n"))
        let yesterday = today.adding(days: -1).isoString
        try write("%% day \(yesterday) %%\n\n## Next actions\n- [ ] Pack 📅 \(yesterday)\n- [ ] Earrings 🔼 Pack\n")
        let morning = try await self.store().load().tasks
        #expect(morning.first { $0.name == "Earrings" }?.due == TaskDue(day: LocalDate(yesterday)))
        #expect(try text().contains("- [ ] Pack 📅 \(yesterday) 🕰️ 🏊 in_today_pool\n    - [ ] Earrings 🏊 in_today_pool\n"))
    }

    /// Parents that name each other stay as they are: no line is lost.
    @Test func aLoopOfParentsLosesNoLine() async throws {
        let (_, tasks) = try await parentAndStore("## Today\n## Next actions\n- [ ] A 🔼 B\n- [ ] B 🔼 A\n")
        #expect(Set(tasks.map(\.name)) == ["A", "B"])
        #expect(try text().contains("A") && text().contains("B"))
    }

    /// Started is the checkbox's slash; the tags of a while ago become it or go, Waiting's section joins Next actions.
    @Test func startedIsTheBoxAndWaitingIsGone() async throws {
        try write("## Soon\n- [/] Begun\n- [ ] Tagged ▶️\n- [ ] Held ⏸️\n## Half year\n- [ ] Far\n## Waiting\n- [ ] Pending\n")
        let tasks = try await store().load().tasks
        #expect(tasks.first { $0.name == "Begun" }?.isStarted == true)
        #expect(tasks.first { $0.name == "Tagged" }?.isStarted == true)
        #expect(tasks.first { $0.name == "Held" }?.isStarted == false)
        #expect(tasks.first { $0.name == "Pending" }?.status == .thisWeek)
        #expect(tasks.first { $0.name == "Far" }?.status == .halfYear)
        let written = try text()
        #expect(written.contains("- [/] Tagged"))
        #expect(!written.contains("▶️") && !written.contains("⏸️") && !written.contains("Waiting") && !written.contains("Half year"))
    }

    /// In a file of the older format the alarm clock was only a time: nothing starts to ring. A real alarm stays one.
    @Test func olderLinesKeepTheirMeaning() async throws {
        let day = today.isoString
        try write("## Today\n- [ ] Plain 📅 \(day) ⏰ 10:00\n- [ ] Rings 📅 \(day) ⏰ 11:00 🚨 default\n- [ ] Tune 📅 \(day) ⏰ 12:00 🚨 chime\n")
        let tasks = try await store().load().tasks
        #expect(tasks.first { $0.name == "Plain" }?.alarms.isEmpty == true)
        #expect(tasks.first { $0.name == "Rings" }?.alarms == [TimeAlarm()])
        #expect(tasks.first { $0.name == "Tune" }?.alarms == [TimeAlarm(sound: "chime")])
        let written = try text()
        #expect(written.contains("%% format 2 %%"))
        #expect(written.contains("- [ ] Plain 📅 \(day) 🕐 10:00\n"))
        #expect(written.contains("- [ ] Rings 📅 \(day) ⏰ 11:00\n"))
        #expect(written.contains("- [ ] Tune 📅 \(day) ⏰ 12:00 🎵 chime\n"))
    }

    /// The clock for a time, the alarm clock for one that rings, back to the clock when the alarm goes.
    @Test func anAlarmSwapsTheTimesMarker() async throws {
        let store = store()
        let day = today.isoString
        let task = try await store.create(draft([.due(TaskDue(day: today, time: LocalTime("15:00")))]), named: "Call")
        #expect(try text().contains("- [ ] Call 📅 \(day) 🕐 15:00"))
        let ringing = try await store.apply([.alarms([TimeAlarm()])], to: task).task
        #expect(try text().contains("- [ ] Call 📅 \(day) ⏰ 15:00\n"))
        #expect(try await store.load().tasks.first?.alarms == [TimeAlarm()], "and it is read back so")
        _ = try await store.apply([.alarms([])], to: ringing)
        #expect(try text().contains("- [ ] Call 📅 \(day) 🕐 15:00\n"))
    }

    @Test func anOldOpenMarkIsNoPartOfTheNameAndGoesWithTheNextWrite() async throws {
        try write("## Today\n- [ ] One ^open\n- [ ] Two\n")
        let store = store()
        let task = try #require(try await store.load().tasks.first { $0.name == "One" })
        _ = try await store.apply([.highPriority(true)], to: task)
        #expect(try text().contains("^open") == false)
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
        await store.mirror(DayMirror(sections: [], timed: [:]))
        let line = try #require(try line(of: "Gym"))
        #expect(try section(of: "Gym") == "Next actions")
        #expect(line.contains("📅 \(today.adding(days: 2).isoString) 🕐 09:30"))
        #expect(line.contains("🔁 every-"))
    }

    @Test func aHabitClosedTodayGoesToDoneAndItsNextDayToSoon() async throws {
        let store = store()
        let daily = RecurrenceRule(startDate: today, startTime: nil, frequency: .daily, interval: 1, byDay: [], byMonthDay: [], byMonth: [],
                                   count: nil, untilDate: nil, untilTime: nil, weekStart: .monday)
        let habit = try await store.create(habitDraft(daily), named: "Read")
        _ = try await store.apply([.mark(.done, on: today)], to: habit)
        await store.mirror(DayMirror(sections: [.init(title: "Day", names: ["Read"])], timed: [:]))
        #expect(try section(of: "Read") == "Next actions")
        #expect(try line(of: "Read")?.contains("📅 \(today.adding(days: 1).isoString)") == true)
        #expect(try text().contains("- [x] Read ✅ \(today.isoString)"))
    }

    /// A day later what was missed keeps its date (a deadline), loses the time it was meant for and is marked overdue.
    @Test func aTaskMissedAtItsTimeIsCarriedWithoutItAndMarked() async throws {
        let yesterday = today.adding(days: -1)
        try write("## Today\n- [ ] Call 📅 \(yesterday.isoString) ⏰ 14:00 🆔 c1\n- [ ] Plain 📅 \(yesterday.isoString) 🆔 p1\n")
        let tasks = try await store().load().tasks
        let call = try #require(tasks.first { $0.name == "Call" })
        let plain = try #require(tasks.first { $0.name == "Plain" })
        #expect(call.isOverdue && call.due == TaskDue(day: yesterday) && call.isInTodayPool && call.alarms.isEmpty)
        #expect(plain.isOverdue && plain.due == TaskDue(day: yesterday) && plain.isInTodayPool)
        #expect(try text().contains("- [ ] Call 📅 \(yesterday.isoString) 🕰️ 🏊 in_today_pool\n"))
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

final class Counter: @unchecked Sendable {
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
        entry.time = LocalTime("10:00")
        entry.alarm = "chime"
        let line = entry.line(format: format)
        #expect(line.contains("⏰ 10:00 🎵 chime"))
        #expect(TaskEntry(line: line, format: format)?.alarm == "chime")
    }

    @Test func theDefaultSoundIsAWordInTheLineAndNilInTheApp() throws {
        var entry = TaskEntry(name: "Dentist")
        var task = TaskItem(id: TaskID("1"), name: "Dentist", status: .thisWeek)
        task.alarms = [TimeAlarm()]
        entry.update(from: task, format: format)
        #expect(entry.alarm == format.alarmDefaultSound)
        #expect(entry.item(in: .soon, parentName: nil, order: nil, format: format).alarms == [TimeAlarm()])
    }

}
