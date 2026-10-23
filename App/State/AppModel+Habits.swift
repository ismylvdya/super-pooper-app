import Foundation

extension AppModel {
    /// Active habits in the user's order; the rest alphabetically after them.
    var habits: [TaskNote] {
        HabitOrder.sorted(tasks.filter { $0.isHabit && !$0.isArchived }, order: settings.habits.order)
    }

    var archivedHabits: [TaskNote] {
        tasks.filter { $0.isHabit && $0.isArchived }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Tap on a habit's day: none → Done (→ Twice) → none.
    func cycleHabit(_ name: String, on day: LocalDate) async {
        guard let habit = task(named: name) else { return }
        let next = HabitMarking.next(after: HabitInstances(task: habit).mark(on: day), twiceADay: habit.habit.twiceADay)
        await setHabitMark(name, on: day, to: next)
    }

    func setHabitMark(_ name: String, on day: LocalDate, to mark: HabitMark?) async {
        guard let habit = task(named: name), day <= context().today else { return }
        await write(habit, TaskMarking(today: context().today).changes(marking: habit, as: mark, on: day))
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
        let current = HabitInstances(task: note).mark(on: day)
        let mark = HabitMarking.notificationMark(pressed, current: current, remindersPerDay: note.habitTimes.count)
        await setHabitMark(name, on: day, to: mark)
    }

    /// Creates the note of a draft (a task or a habit) with all its fields. Returns the final name.
    func create(_ draft: NoteDraft, named name: String) async -> String? {
        do {
            let created = try await services.tasks.create(named: name, status: draft.note.status)
            let result = try await services.tasks.apply(draft.changes.filter(\.isFieldOfNewNote), to: created)
            replace(result.task)
            await publishDerivedState()
            return result.task.name
        } catch {
            banners.show(Self.describe(error), style: .problem)
            return nil
        }
    }

    /// A new habit: daily from today, shown in Today as the settings say.
    func newHabitDraft() -> NoteDraft {
        NoteDraft(status: .habit, changes: [
            .recurrence(RecurrenceDraft(start: context().today).raw),
            .showInToday(settings.habits.showInTodayByDefault),
        ])
    }

    private static func habitMark(for action: ActionID) -> HabitMark? {
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
