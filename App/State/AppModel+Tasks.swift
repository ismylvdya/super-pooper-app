import Foundation

/// Intents about tasks and habits: menu and notification actions, edits, marks, new notes, rename, delete, subtasks and
/// the text, the trash and versions in conflict.
extension AppModel {
    func task(named name: String) -> TaskItem? { parts.tasks.task(named: name) }

    /// A menu action on a note; `day`: a habit mark for that day (habit page, notifications), `nil` = today.
    func perform(_ action: ActionID, on name: String, day: LocalDate? = nil) async {
        guard task(named: name) != nil else { return }
        _ = await run(action, on: name, day: day, announcing: true)
    }

    /// An action from a menu or a swipe: one that can be taken back happens at once and the banner offers Undo
    /// (`UndoController`); any other runs as `perform` does.
    func performOfferingUndo(_ action: ActionDefinition, on name: String) async {
        guard parts.undo.canUndo(action), let step = parts.undo.begin(action.id, on: name) else {
            await perform(action.id, on: name)
            return
        }
        guard let trashed = await run(action.id, on: name, day: nil, announcing: false) else { return }
        parts.undo.offer(step, trashed: trashed)
    }

    /// Select mode: the action on every selected note, and one Undo in the banner for all of them (`BatchEdits`).
    /// `day`: the shown day, for a habit's mark and Not today (nil = today).
    func performOfferingUndo(_ action: ActionDefinition, on names: [String], day: LocalDate?) async {
        let step = parts.undo.canUndo(action) ? parts.undo.begin(action.id, on: names) : nil
        var trashed: [TrashedNote] = []
        switch action.id {
        case .highPriority:
            let isHigh = BatchEdits.highPriority(for: names.compactMap(task(named:)))
            for name in names { await parts.writer.edit(name) { _ in [.highPriority(isHigh)] } }
        default:
            // A subtask may have gone along with its parent already.
            for name in names where task(named: name) != nil {
                trashed += await run(action.id, on: name, day: day, announcing: step == nil) ?? []
            }
        }
        if let step { parts.undo.offer(step, trashed: trashed) }
    }

    /// The action needs its confirmation first: it has one, and it cannot be taken back here.
    func needsConfirmation(_ action: ActionDefinition) -> Bool {
        action.needsConfirmation && !parts.undo.canUndo(action)
    }

    /// The banner's Undo: what the latest action offering it changed goes back.
    func undo(_ id: UUID) async { await parts.undo.undo(id) }

    /// Runs the action; returns where deleted notes lie in the trash (none for other actions), nil when it failed.
    private func run(_ action: ActionID, on name: String, day: LocalDate?, announcing: Bool) async -> [TrashedNote]? {
        switch action {
        case .done, .partial, .twice, .unmark: await parts.notes.markFromMenu(name, as: action.habitMark, on: day)
        case .skipToday: await parts.dayCommands.skip(name, on: day)
        case .notToday: await parts.dayCommands.notToday(name, on: day)
        case .backToToday: parts.dayCommands.unpostpone(name)
        case .archive: return await parts.notes.archive(name, announcing: announcing) ? [] : nil
        case .restoreThisWeek, .notStarted: await parts.notes.setStatus(.thisWeek, of: name)
        case .start: await parts.notes.setStatus(.inProgress, of: name)
        case .restoreHalfYear: await parts.notes.setStatus(.halfYear, of: name)
        case .restoreHabit: await parts.notes.setStatus(.habit, of: name)
        case .restoreFromArchive: await parts.notes.restoreFromArchive(name)
        case .returnFromDone: await parts.notes.returnToSoon(name)
        case .delete: return await parts.notes.delete(name, announcing: announcing)
        case .highPriority: await parts.writer.edit(name) { [.highPriority(!$0.isHighPriority)] }
        // Opening is the screen's; the trash restores its own notes, the timeline deletes its events, a notification
        // snoozes or dismisses itself.
        case .open, .openInObsidian, .restoreFromTrash, .deleteEvent, .snooze, .dismissAlert: break
        case .unworm: unworm([name], on: day)
        // Select mode is the screen's; Worm and New section take the selected tasks (`worm`, `newSection`).
        case .select, .worm, .newSection: break
        }
        return []
    }

    /// An action on a task of the done folder (the Done list): its name may also be an active note's, so it goes by id.
    /// An action on a task of the done folder: a delete that the trash can take back happens at once and the banner
    /// offers Undo, which puts the task back into the done folder as it was.
    func performOfferingUndo(_ action: ActionDefinition, onFiled id: TaskID) async {
        guard action.id == .delete, parts.undo.canUndo(action), let task = parts.tasks.filedTask(id) else {
            await perform(action.id, onFiled: id)
            return
        }
        let step = parts.undo.begin(action.id, onFiled: task)
        guard let trashed = await parts.notes.deleteFiled(id, announcing: false) else { return }
        parts.undo.offer(step, trashed: trashed)
    }

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
    func newItemPage(kind: NewItemSeed.Kind) -> NewItemPage { parts.notes.newItemPage(kind: kind) }
    /// A date typed into a name ("tomorrow 18:20"), by now's logical day.
    func detectDate(in name: String) -> DetectedDate? { parts.dates.detect(in: name, context: context()) }

    /// The new-item page is left; true once the page is done with (see `NoteCommands.create(from:unnamed:)`).
    func create(from page: NewItemPage, unnamed: String) async -> Bool { await parts.notes.create(from: page, unnamed: unnamed) }
    func create(_ draft: NoteDraft, named name: String) async -> String? { await parts.notes.create(draft, named: name) }
    /// Return in the new-item page's name: the note is created at once; its name, or nil when nothing was saved.
    func createOnReturn(from page: NewItemPage) async -> String? { await parts.notes.createOnReturn(from: page) }
    /// A task named outside the app's pages (the New Task intent), with the new task page's defaults.
    func createTask(named name: String) async -> NamedTaskCreation { await parts.notes.createTask(named: name) }

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
    /// The note of that name in the trash, the latest put there (as the trash screen last read it).
    func trashedNote(named name: String) -> TrashedNote? { trashedNotes.first { $0.name.isSameNoteName(as: name) } }
    /// "Restore from trash" on the page of a note in the trash.
    func restoreFromTrash(named name: String) async {
        if let note = trashedNote(named: name) { await restore(note) }
    }
    func deletePermanently(_ note: TrashedNote) async { await parts.trash.deletePermanently(note) }

    func versions(of name: String) async -> [NoteVersion] { await parts.conflicts.versions(of: name) }
    func keep(_ version: NoteVersion, of name: String) async { await parts.conflicts.keep(version, of: name) }
}
