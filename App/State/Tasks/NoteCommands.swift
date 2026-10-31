import Foundation

/// What the user does to a task or habit as a whole: marks and statuses, a new note (with its subtasks), a rename (the
/// notes that refer to it, the settings and today's state follow), a delete, the subtasks' order, the link to the app
/// its store belongs to. Field edits go through `NoteWriter`.
@MainActor
final class NoteCommands {
    private let tasks: TaskState
    private let writer: NoteWriter
    private let texts: NoteTextEditor
    private let store: TaskStore
    private let links: ExternalLinking?
    private let backups: BackupPolicy
    private let settings: SettingsController
    private let day: DayStateController
    private let derived: DerivedStatePublisher
    private let appEvents: AppEventSink

    init(tasks: TaskState, writer: NoteWriter, texts: NoteTextEditor, store: TaskStore, links: ExternalLinking?,
         backups: BackupPolicy, settings: SettingsController, day: DayStateController, derived: DerivedStatePublisher,
         appEvents: AppEventSink) {
        self.tasks = tasks
        self.writer = writer
        self.texts = texts
        self.store = store
        self.links = links
        self.backups = backups
        self.settings = settings
        self.day = day
        self.derived = derived
        self.appEvents = appEvents
    }

    // MARK: - Marks and statuses

    /// A mark from a menu (`nil`: Unmark) for `day` (habit page, notifications) or today. Done on a habit goes on to
    /// Twice for a twice-a-day habit already done (`HabitMarking.menuDone`).
    func markFromMenu(_ name: String, as mark: HabitMark?, on day: LocalDate?) async {
        guard let task = tasks.task(named: name) else { return }
        let today = self.day.context().today
        let chosen = mark == .done && task.isHabit
            ? HabitMarking.menuDone(current: task.mark(on: day ?? today), twiceADay: task.isTwiceADay) : mark
        await writer.write(task, TaskMarking(today: today).changes(marking: task, as: chosen, on: day))
    }

    /// Tap on a habit's day: none → Done (→ Twice) → none.
    func cycleHabit(_ name: String, on day: LocalDate) async {
        await markHabit(name, on: day) { habit in HabitMarking.next(after: habit.mark(on: day), twiceADay: habit.isTwiceADay) }
    }

    func setHabitMark(_ name: String, on day: LocalDate, to mark: HabitMark?) async {
        await markHabit(name, on: day) { _ in mark }
    }

    /// A button on a delivered notification of a habit: the second Done of a day with two reminders is Twice.
    func markFromNotification(_ name: String, pressed: HabitMark, on day: LocalDate) async {
        await markHabit(name, on: day) { habit in
            HabitMarking.notificationMark(pressed, current: habit.mark(on: day), remindersPerDay: habit.habitTimes.count)
        }
    }

    /// The new mark is chosen from the habit as the previous edit left it; a day still to come is not marked.
    private func markHabit(_ name: String, on day: LocalDate, mark: @escaping (TaskItem) -> HabitMark?) async {
        let today = self.day.context().today
        guard day <= today else { return }
        await writer.edit(name) { habit in TaskMarking(today: today).changes(marking: habit, as: mark(habit), on: day) }
    }

    /// The one way to change a status (archive, restore, promote, the review, the page): `TaskMarking` decides the edits,
    /// so leaving done always drops the day of completion.
    @discardableResult
    func setStatus(_ status: TaskStatus, of name: String) async -> Bool {
        guard let task = tasks.task(named: name) else { return false }
        return await writer.write(task, TaskMarking(today: day.context().today).changes(setting: status, on: task))
    }

    func archive(_ name: String) async {
        if await setStatus(.archived, of: name) { appEvents.send(.archived(name)) }
    }

    /// The weekly review on the phone: a task of a later planning level joins this week.
    func moveToThisWeek(_ name: String) async {
        guard let task = tasks.task(named: name), task.canPromote else { return }
        if await setStatus(.thisWeek, of: name) { appEvents.send(.promoted([name])) }
    }

    // MARK: - New notes and subtasks

    /// What is wrong with a name a note is about to get; nil for a name it can take.
    func nameProblem(in name: String) -> NoteNameProblem? {
        store.nameProblem(in: name)
    }

    /// A new habit: daily from today, shown in Today as the settings say.
    func newHabitDraft() -> NoteDraft {
        .newHabit(startingOn: day.context().today, showInToday: settings.settings.habits.showNewHabitsInToday)
    }

    /// The new task or habit page is left: its note is created (none for a page left untouched), or the user is told why
    /// its name cannot be used. `unnamed`: the name of a note whose name was left empty. True once the page is done with.
    func create(from page: NewNotePage, unnamed: String) async -> Bool {
        if let problem = page.nameProblem(nameProblem(in:)) {
            appEvents.send(.nameRejected(problem, name: page.name))
            return false
        }
        guard let creation = page.creation(unnamed: unnamed, rules: nameProblem(in:)) else { return false }
        return await create(creation.draft, named: creation.name) != nil
    }

    /// Creates the note of a draft (a task or a habit) with all its fields, its text and its subtasks (each a task of its
    /// own linked to its parent). Returns the final name.
    func create(_ draft: NoteDraft, named name: String) async -> String? {
        do {
            let created = try await store.create(draft, named: name)
            tasks.written(created)
            for subtask in draft.subtasks.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !subtask.isEmpty {
                try await createSubtask(subtask, of: created.name)
            }
            await derived.publish()
            appEvents.send(.created(created.name))
            return created.name
        } catch {
            appEvents.send(.failure(AppFailure(error)))
            return nil
        }
    }

    /// A task of this week that is a subtask of `parent`.
    func addSubtask(_ name: String, to parent: String) async {
        do {
            try await createSubtask(name, of: parent)
            await derived.publish()
        } catch {
            appEvents.send(.failure(AppFailure(error)))
        }
    }

    /// A subtask dragged onto another one on the parent's page takes its place; the list (and the pool) shows the new
    /// order at once, the places are written to the subtasks after.
    func moveSubtask(_ name: String, onto target: String, of parent: String) {
        for (subtask, place) in SubtaskOrder.moving(name, onto: target, in: tasks.subtasks(of: parent)) {
            guard let seen = tasks.task(named: subtask) else { continue }
            tasks.replace(seen.applying([.subtaskOrder(place)]))
            // Written as read before, so the new place is not taken for a change made elsewhere.
            Task { await writer.write(seen, [.subtaskOrder(place)]) }
        }
        Task { await derived.publish() }
    }

    private func createSubtask(_ name: String, of parent: String) async throws {
        tasks.written(try await store.create(.subtask(of: parent), named: name))
    }

    // MARK: - Rename and delete

    func delete(_ name: String) async {
        guard let task = tasks.task(named: name) else { return }
        do {
            try await backups.backup([task], reason: "delete")
            try await store.delete(task)
            tasks.remove(task)
            appEvents.send(.deleted(task.name))
            await derived.publish()
        } catch {
            appEvents.send(.failure(AppFailure(error)))
        }
    }

    /// Renames the note; the store rewrites the tasks that refer to it, and the settings and today's state that name it
    /// follow the new name. What was typed into its text a moment ago is written first.
    @discardableResult
    func rename(_ name: String, to newName: String) async -> Bool {
        guard let task = tasks.task(named: name) else { return false }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != name else { return true }
        await texts.flush(name)
        let dependents = NameReferences.referring(to: name, in: tasks.tasks)
        var renamed = false
        do {
            try await backups.backup([task] + dependents, reason: "rename")
            let result = try await store.rename(task, to: trimmed, dependents: dependents)
            tasks.remove(task)
            tasks.written(result)
            renamed = true
            followRename(from: name, to: trimmed)
            appEvents.send(.renamed(trimmed))
        } catch {
            appEvents.send(.failure(AppFailure(error)))
        }
        await tasks.reload(from: store)
        await derived.publish()
        return renamed
    }

    /// The link that opens the note in the app its store belongs to (Obsidian); nil where the store has none.
    func externalURL(for name: String) async -> URL? {
        guard let task = tasks.task(named: name), let links else { return nil }
        return await links.externalURL(for: task)
    }

    private func followRename(from old: String, to new: String) {
        let rename = { (names: [String]) in NameReferences.renaming(names, from: old, to: new) }
        settings.update {
            $0.habits.order = rename($0.habits.order)
            $0.habits.morningRoutine = rename($0.habits.morningRoutine)
            $0.habits.dayRoutine = rename($0.habits.dayRoutine)
            $0.habits.eveningRoutine = rename($0.habits.eveningRoutine)
        }
        day.followRename(from: old, to: new)
    }
}
