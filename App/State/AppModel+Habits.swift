import Foundation

extension AppModel {
    /// Active habits in the user's order; the rest alphabetically after them.
    var habits: [TaskNote] {
        HabitOrder.sorted(tasks.filter { $0.isHabit && !$0.isArchived }, order: settings.habits.order)
    }

    var archivedNotesCount: Int { archivedTasks.count + archivedHabits.count }

    var archivedHabits: [TaskNote] {
        NameOrder.sorted(tasks.filter { $0.isHabit && $0.isArchived })
    }

    /// Tap on a habit's day: none → Done (→ Twice) → none.
    func cycleHabit(_ name: String, on day: LocalDate) async {
        await markHabit(name, on: day) { habit in
            HabitMarking.next(after: HabitInstances(task: habit).mark(on: day), twiceADay: habit.habit.twiceADay)
        }
    }

    func setHabitMark(_ name: String, on day: LocalDate, to mark: HabitMark?) async {
        await markHabit(name, on: day) { _ in mark }
    }

    /// The new mark is chosen from the habit as the previous edit left it.
    private func markHabit(_ name: String, on day: LocalDate, mark: @escaping (TaskNote) -> HabitMark?) async {
        let today = context().today
        guard day <= today else { return }
        await edit(name) { habit in TaskMarking(today: today).changes(marking: habit, as: mark(habit), on: day) }
    }

    func moveHabits(_ names: [String]) {
        updateSettings { $0.habits.order = names }
    }

    /// A button on a delivered notification, for the day the notification belongs to.
    /// Habits: the second Done of a day with two reminders is Twice. Tasks are simply done.
    func performNotificationAction(_ action: ActionID, on name: String, day: LocalDate?) async {
        guard let note = task(named: name) else { return }
        let day = day ?? context().today
        guard note.isHabit, let pressed = Self.habitMark(for: action) else {
            await perform(action, on: name, day: day == context().today ? nil : day)
            return
        }
        await markHabit(name, on: day) { habit in
            HabitMarking.notificationMark(pressed, current: HabitInstances(task: habit).mark(on: day), remindersPerDay: habit.habitTimes.count)
        }
    }

    /// Creates the note of a draft (a task or a habit) with all its fields, its text and its subtasks
    /// (each a task of its own linked by `projects`, as TaskNotes does). Returns the final name.
    func create(_ draft: NoteDraft, named name: String) async -> String? {
        do {
            let created = try await services.tasks.create(named: name, status: draft.note.status)
            var result = try await services.tasks.apply(draft.changes.filter(\.isFieldOfNewNote), to: created)
            if !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result = try await services.tasks.setBody(draft.body, of: result.task)
            }
            noteWrite(result.task)
            replace(result.task)
            for subtask in draft.subtasks.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !subtask.isEmpty {
                try await createSubtask(subtask, of: result.task.name)
            }
            await publishDerivedState()
            return result.task.name
        } catch {
            banners.show(Self.describe(error), style: .problem)
            return nil
        }
    }

    /// A task of this week that is a subtask of `parent`.
    func addSubtask(_ name: String, to parent: String) async {
        do {
            try await createSubtask(name, of: parent)
            await publishDerivedState()
        } catch {
            banners.show(Self.describe(error), style: .problem)
        }
    }

    /// Subtasks of a note (notes whose `projects` link to it), by name.
    func subtasks(of parent: String) -> [TaskNote] {
        NameOrder.sorted(tasks.filter { $0.projects.contains { $0.isSameNoteName(as: parent) } })
    }

    private func createSubtask(_ name: String, of parent: String) async throws {
        let created = try await services.tasks.create(named: name, status: .thisWeek)
        let subtask = try await services.tasks.apply([.addProject(parent)], to: created).task
        noteWrite(subtask)
        replace(subtask)
    }

    /// A new habit: daily from today, shown in Today as the settings say.
    func newHabitDraft() -> NoteDraft {
        NoteDraft(status: .habit, changes: [
            .recurrence(RecurrenceDraft(start: context().today).raw),
            .showInToday(settings.habits.showInTodayByDefault),
        ])
    }

    /// The mark a menu or notification action sets (`nil`: Unmark).
    static func habitMark(for action: ActionID) -> HabitMark? {
        switch action {
        case .done: .done
        case .partial: .partial
        case .twice: .twice
        default: nil
        }
    }
}

private extension TaskFieldChange {
    /// The status is written when the file is created.
    var isFieldOfNewNote: Bool {
        if case .status = self { return false }
        return true
    }
}
