import Foundation

extension AppModel {
    /// `day`: a habit mark for that day (habit page, notifications); `nil` = today.
    func perform(_ action: ActionID, on name: String, day: LocalDate? = nil) async {
        guard let task = task(named: name) else { return }
        let marking = TaskMarking(today: context().today)
        switch action {
        case .done where task.isHabit:
            let current = task.mark(on: day ?? context().today)
            await write(task, marking.changes(marking: task, as: HabitMarking.menuDone(current: current, twiceADay: task.isTwiceADay), on: day))
        case .done, .partial, .twice:
            let mark: HabitMark = action == .partial ? .partial : action == .twice ? .twice : .done
            await write(task, marking.changes(marking: task, as: mark, on: day))
        case .unmark:
            await write(task, marking.changes(marking: task, as: nil, on: day))
        case .skipToday:
            guard day == nil || day == context().today else { return }
            updateDayState { if !$0.skipped.containsNoteName(name) { $0.skipped.append(name) } }
            await publishDerivedState()
        case .notToday:
            guard day == nil || day == context().today, let local = localTask(named: name) else { return }
            let changes = NotToday.changes(for: local, context: context())
            if changes.isEmpty { postpone(name) } else { await writeLocal(task, changes) }
        case .archive:
            if await setStatus(.archived, of: name) { appEvents.send(.archived(name)) }
        case .restoreThisWeek:
            await setStatus(.thisWeek, of: name)
        case .restoreHalfYear:
            await setStatus(.halfYear, of: name)
        case .restoreHabit:
            await setStatus(.habit, of: name)
        case .delete:
            await delete(task)
        case .open, .openInObsidian, .deleteEvent:
            break
        }
    }

    /// The one way to change a status (archive, restore, promote, the review, the page): `TaskMarking` decides the edits,
    /// so leaving done always drops the day of completion.
    @discardableResult
    func setStatus(_ status: TaskStatus, of name: String) async -> Bool {
        guard let task = task(named: name) else { return false }
        return await write(task, TaskMarking(today: context().today).changes(setting: status, on: task))
    }

    func update(_ name: String, _ changes: [TaskEdit]) async {
        await edit(name) { _ in changes }
    }

    /// A date picked on the day's view of a task (This week): on the phone's clock, written in the note's own zone.
    func setLocalDue(_ due: TaskDue?, of name: String) async {
        await edit(name) { note in ZonedTimes.stored([.due(due)], of: note, calendar: self.calendar) }
    }

    /// Changes decided on the day's view of `task` (`localTasks`) go back into the note's own zone before writing.
    @discardableResult
    func writeLocal(_ task: TaskItem, _ changes: [TaskEdit]) async -> Bool {
        await write(task, ZonedTimes.stored(changes, of: task, calendar: calendar))
    }

    /// Edits of one note run one after another, and each decides from the note as the edit before it left it:
    /// a second quick tap (a toggle, a habit mark) does not repeat the first one's decision.
    func edit(_ name: String, _ changes: @escaping (TaskItem) -> [TaskEdit]) async {
        let edit = enqueueEdit(name, changes)
        await edit.value
        if pendingEdits[name] == edit { pendingEdits[name] = nil }
    }

    /// The edit takes its place in the note's line at once and runs when the edits before it are done.
    @discardableResult
    func enqueueEdit(_ name: String, _ changes: @escaping (TaskItem) -> [TaskEdit]) -> Task<Void, Never> {
        let previous = pendingEdits[name]
        let edit = Task { @MainActor in
            await previous?.value
            guard let note = self.task(named: name) else { return }
            await self.write(note, changes(note))
        }
        pendingEdits[name] = edit
        return edit
    }

    @discardableResult
    func write(_ task: TaskItem, _ changes: [TaskEdit]) async -> Bool {
        guard !changes.isEmpty else { return true }
        do {
            let result = try await services.tasks.apply(changes, to: task)
            noteWrite(result.task)
            replace(result.task)
            reportClashes(result, name: task.name)
            await publishDerivedState()
            if DoneFiling.isDue(result.task) { await fileAwayDoneTasks() }
            return true
        } catch {
            appEvents.send(.failure(AppFailure(error)))
            return false
        }
    }

    /// Merged edits are silent; a field changed both here and elsewhere is reported.
    func reportClashes(_ result: TaskWriteResult, name: String) {
        if let clashes = AppEvent.clashes(in: result, of: name) { appEvents.send(clashes) }
    }

    func delete(_ task: TaskItem) async {
        do {
            try await backup([task], reason: "delete")
            try await services.tasks.delete(task)
            remove(task)
            appEvents.send(.deleted(task.name))
            await publishDerivedState()
        } catch {
            appEvents.send(.failure(AppFailure(error)))
        }
    }

    /// Renames the note; the store rewrites the tasks that refer to it, and the settings and today's state that name it
    /// follow the new name.
    @discardableResult
    func rename(_ name: String, to newName: String) async -> Bool {
        guard let task = task(named: name) else { return false }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != name else { return true }
        await flushBody(of: name)
        let dependents = NameReferences.referring(to: name, in: tasks)
        var renamed = false
        do {
            try await backup([task] + dependents, reason: "rename")
            let result = try await services.tasks.rename(task, to: trimmed, dependents: dependents)
            remove(task)
            noteWrite(result)
            replace(result)
            renamed = true
            followRename(from: name, to: trimmed)
            appEvents.send(.renamed(trimmed))
        } catch {
            appEvents.send(.failure(AppFailure(error)))
        }
        // Whatever happened, the files are the truth: re-read them.
        if let result = try? await services.tasks.load() { setScanResult(result) }
        await publishDerivedState()
        return renamed
    }

    private func followRename(from old: String, to new: String) {
        let rename = { (names: [String]) in NameReferences.renaming(names, from: old, to: new) }
        updateSettings {
            $0.habits.order = rename($0.habits.order)
            $0.habits.morningRoutine = rename($0.habits.morningRoutine)
            $0.habits.dayRoutine = rename($0.habits.dayRoutine)
            $0.habits.eveningRoutine = rename($0.habits.eveningRoutine)
        }
        updateDayState {
            $0.skipped = rename($0.skipped)
            $0.postponed = rename($0.postponed)
            $0.manualOrder = $0.manualOrder.map(rename)
        }
    }

    /// The link that opens the note in the app its store belongs to (Obsidian); nil where the store has none.
    func externalURL(for name: String) async -> URL? {
        guard let task = task(named: name), let links = services.links else { return nil }
        return await links.externalURL(for: task)
    }

    /// A copy of the notes before a risky change, when backups are on and the store makes them.
    func backup(_ tasks: [TaskItem], reason: String) async throws {
        guard config.flags.backups, let backups = services.backups else { return }
        try await backups.backup(tasks, reason: reason)
    }

    /// What is wrong with a name a note is about to get; nil for a name it can take.
    func nameProblem(in name: String) -> NoteNameProblem? {
        services.tasks.nameProblem(in: name)
    }

    // MARK: - Pool order

    /// The morning review takes a task out of today; it stays this week and is back tomorrow.
    func postpone(_ name: String) {
        updateDayState { if !$0.postponed.containsNoteName(name) { $0.postponed.append(name) } }
        Task { await publishDerivedState() }
    }

    func unpostpone(_ name: String) {
        updateDayState { $0.postponed.removeAll { $0.isSameNoteName(as: name) } }
        Task { await publishDerivedState() }
    }

    var postponedTasks: [TaskItem] {
        let names = dayState.day == context().today ? dayState.postponed : []
        return names.compactMap(task(named:))
    }

    func setManualOrder(_ names: [String]) {
        updateDayState { $0.manualOrder = names }
        Task { await publishDerivedState() }
    }

    /// A drag in This week across the Morning / Day / Evening groups: the new order, and a new part of the day
    /// for the tasks that changed group.
    func applyReviewMove(_ move: ReviewGroups.Move) {
        setManualOrder(move.order)
        for (name, group) in move.regrouped {
            enqueueEdit(name) { _ in [.timeOfDay(group.timeOfDay)] }
        }
    }

    /// The weekly review on the phone: a task of a later planning level joins this week.
    func moveToThisWeek(_ name: String) async {
        guard let task = task(named: name), task.canPromote else { return }
        if await setStatus(.thisWeek, of: name) { appEvents.send(.promoted([name])) }
    }

    func resetOrder() {
        updateDayState { $0.manualOrder = nil }
        appEvents.send(.orderReset)
        Task { await publishDerivedState() }
    }

}
