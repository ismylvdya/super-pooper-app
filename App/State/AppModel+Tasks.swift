import Foundation

/// Intents about tasks and habits: menu and notification actions, edits, marks, new notes, rename, delete, subtasks and
/// the text, the trash and versions in conflict.
extension AppModel {
    func task(named name: String) -> TaskItem? { parts.tasks.task(named: name) }

    /// A menu action on a note; `day`: a habit mark for that day (habit page, notifications), `nil` = today.
    func perform(_ action: ActionID, on name: String, day: LocalDate? = nil) async {
        guard task(named: name) != nil else { return }
        switch action {
        case .done, .partial, .twice, .unmark: await parts.notes.markFromMenu(name, as: action.habitMark, on: day)
        case .skipToday: await parts.dayCommands.skip(name, on: day)
        case .notToday: await parts.dayCommands.notToday(name, on: day)
        case .backToToday: parts.dayCommands.unpostpone(name)
        case .archive: await parts.notes.archive(name)
        case .restoreThisWeek: await parts.notes.setStatus(.thisWeek, of: name)
        case .restoreHalfYear: await parts.notes.setStatus(.halfYear, of: name)
        case .restoreHabit: await parts.notes.setStatus(.habit, of: name)
        case .returnFromDone: await parts.notes.returnToSoon(name)
        case .delete: await parts.notes.delete(name)
        // Opening is the screen's; the trash restores its own notes, the timeline deletes its events.
        case .open, .openInObsidian, .restoreFromTrash, .deleteEvent: break
        }
    }

    /// An action on a task of the done folder (the Done list): its name may also be an active note's, so it goes by id.
    func perform(_ action: ActionID, onFiled id: TaskID) async {
        switch action {
        case .returnFromDone: await parts.notes.returnFiled(id)
        case .delete: await parts.notes.deleteFiled(id)
        default: break
        }
    }

    /// A button on a delivered notification, for the day the notification belongs to. Habits: the second Done of a day
    /// with two reminders is Twice. Tasks are simply done.
    func performNotificationAction(_ action: ActionID, on name: String, day: LocalDate?) async {
        guard let note = task(named: name) else { return }
        let today = context().today
        let day = day ?? today
        guard note.isHabit, let pressed = action.habitMark else {
            await perform(action, on: name, day: day == today ? nil : day)
            return
        }
        await parts.notes.markFromNotification(name, pressed: pressed, on: day)
    }

    /// Edits decided from the note as it is when they run (two quick taps go there and back).
    func edit(_ name: String, _ changes: @escaping (TaskItem) -> [TaskEdit]) async { await parts.writer.edit(name, changes) }
    func update(_ name: String, _ changes: [TaskEdit]) async { await parts.writer.edit(name) { _ in changes } }

    /// A date picked on the day's view of a task (Soon): on the phone's clock, written in the note's own zone.
    func setLocalDue(_ due: TaskDue?, of name: String) async { await parts.writer.setLocalDue(due, of: name) }

    @discardableResult
    func setStatus(_ status: TaskStatus, of name: String) async -> Bool { await parts.notes.setStatus(status, of: name) }
    func moveToThisWeek(_ name: String) async { await parts.notes.moveToThisWeek(name) }

    /// Tap on a habit's day: none → Done (→ Twice) → none.
    func cycleHabit(_ name: String, on day: LocalDate) async { await parts.notes.cycleHabit(name, on: day) }
    func setHabitMark(_ name: String, on day: LocalDate, to mark: HabitMark?) async {
        await parts.notes.setHabitMark(name, on: day, to: mark)
    }
    func moveHabits(_ names: [String]) { updateSettings { $0.habits.order = names } }

    func nameProblem(in name: String) -> NoteNameProblem? { parts.notes.nameProblem(in: name) }
    func newHabitDraft() -> NoteDraft { parts.notes.newHabitDraft() }

    /// The new task or habit page is left; true once the page is done with (see `NoteCommands.create(from:unnamed:)`).
    func create(from page: NewNotePage, unnamed: String) async -> Bool { await parts.notes.create(from: page, unnamed: unnamed) }
    func create(_ draft: NoteDraft, named name: String) async -> String? { await parts.notes.create(draft, named: name) }

    @discardableResult
    func rename(_ name: String, to newName: String) async -> Bool { await parts.notes.rename(name, to: newName) }
    func externalURL(for name: String) async -> URL? { await parts.notes.externalURL(for: name) }

    func addSubtask(_ name: String, to parent: String) async { await parts.notes.addSubtask(name, to: parent) }
    func moveSubtask(_ name: String, onto target: String, of parent: String) {
        parts.notes.moveSubtask(name, onto: target, of: parent)
    }

    // MARK: - Text

    func openBody(of name: String) async { await parts.texts.open(name) }
    func editBody(_ text: String, of name: String) { parts.texts.edit(text, of: name) }
    func closeBody(of name: String) { parts.texts.close(name) }
    func flushBody(of name: String) async { await parts.texts.flush(name) }

    // MARK: - Trash and conflicts

    /// The store has a trash (otherwise deleting is for good and there is no trash screen).
    var hasTrash: Bool { parts.capabilities.hasTrash }
    var trashCount: Int? { trashedNotes.isEmpty ? nil : trashedNotes.count }
    func refreshTrash() async { await parts.trash.refresh() }
    func trashedText(_ note: TrashedNote) async -> String { await parts.trash.text(of: note) }
    func restore(_ note: TrashedNote) async { await parts.trash.restore(note) }
    func deletePermanently(_ note: TrashedNote) async { await parts.trash.deletePermanently(note) }

    func versions(of name: String) async -> [NoteVersion] { await parts.conflicts.versions(of: name) }
    func keep(_ version: NoteVersion, of name: String) async { await parts.conflicts.keep(version, of: name) }
}
