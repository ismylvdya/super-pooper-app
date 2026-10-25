import Foundation

extension AppModel {
    /// `day`: a habit mark for that day (habit page, notifications); `nil` = today.
    func perform(_ action: ActionID, on name: String, day: LocalDate? = nil) async {
        guard let task = task(named: name) else { return }
        let marking = TaskMarking(today: context().today)
        switch action {
        case .done, .partial, .twice:
            let mark: HabitMark = action == .partial ? .partial : action == .twice ? .twice : .done
            await write(task, marking.changes(marking: task, as: mark, on: day))
        case .unmark:
            await write(task, marking.changes(marking: task, as: nil, on: day))
        case .skipToday:
            guard day == nil || day == context().today else { return }
            updateDayState { if !$0.skipped.contains(name) { $0.skipped.append(name) } }
            await publishDerivedState()
        case .archive:
            if await write(task, [.status(.archived)]) {
                banners.show(L10n.format("banner.archived", name), style: .success)
            }
        case .restoreThisWeek:
            await write(task, [.status(.thisWeek)])
        case .restoreHalfYear:
            await write(task, [.status(.halfYear)])
        case .restoreHabit:
            await write(task, [.status(.habit)])
        case .delete:
            await delete(task)
        case .open, .openInObsidian, .routines:
            break
        }
    }

    func update(_ name: String, _ changes: [TaskFieldChange]) async {
        guard let task = task(named: name) else { return }
        await write(task, changes)
    }

    @discardableResult
    func write(_ task: TaskNote, _ changes: [TaskFieldChange]) async -> Bool {
        guard !changes.isEmpty else { return true }
        do {
            let result = try await services.tasks.apply(changes, to: task)
            noteWrite(result.task)
            replace(result.task)
            reportClashes(result, name: task.name)
            await publishDerivedState()
            return true
        } catch {
            banners.show(Self.describe(error), style: .problem)
            return false
        }
    }

    /// Merged edits are silent; a key changed both here and elsewhere gets a yellow banner.
    private func reportClashes(_ result: TaskWriteResult, name: String) {
        guard !result.clashingKeys.isEmpty else { return }
        banners.show(L10n.format("banner.conflictSameKey", name, L10n.list(result.clashingKeys)), style: .warning)
    }

    func delete(_ task: TaskNote) async {
        do {
            if config.flags.backups { try await services.tasks.backup([task], reason: "delete") }
            try await services.tasks.moveToTrash(task)
            remove(task)
            banners.show(L10n.format("banner.deleted", task.name), style: .success)
            await publishDerivedState()
        } catch {
            banners.show(Self.describe(error), style: .problem)
        }
    }

    /// Renames the note file; tasks that link to it get their `previous_task` and `projects` updated.
    @discardableResult
    func rename(_ name: String, to newName: String) async -> Bool {
        guard let task = task(named: name) else { return false }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != name else { return true }
        let dependents = tasks.filter { ($0.previousTasks + $0.projects).contains { $0.isSameNoteName(as: name) } }
        var renamed = false
        do {
            if config.flags.backups { try await services.tasks.backup([task] + dependents, reason: "rename") }
            _ = try await services.tasks.rename(task, to: trimmed, dependents: dependents)
            renamed = true
        } catch {
            banners.show(Self.describe(error), style: .problem)
        }
        // Whatever happened, the files are the truth: re-read them.
        if let result = try? await services.tasks.scan() { setScanResult(result) }
        await publishDerivedState()
        return renamed
    }

    func body(of name: String) async -> String? {
        guard let task = task(named: name) else { return nil }
        return try? await services.tasks.body(of: task)
    }

    func setBody(_ body: String, of name: String) async {
        guard let task = task(named: name) else { return }
        do {
            let result = try await services.tasks.setBody(body, of: task)
            noteWrite(result.task)
            replace(result.task)
            reportClashes(result, name: task.name)
        } catch {
            banners.show(Self.describe(error), style: .problem)
        }
    }

    func obsidianURL(for name: String) async -> URL? {
        guard let task = task(named: name) else { return nil }
        return await services.tasks.obsidianURL(for: task)
    }

    // MARK: - Pool order

    /// The morning review takes a task out of today; it stays this week and is back tomorrow.
    func postpone(_ name: String) {
        Haptics.play(.light)
        updateDayState { if !$0.postponed.contains(name) { $0.postponed.append(name) } }
        Task { await publishDerivedState() }
    }

    func unpostpone(_ name: String) {
        Haptics.play(.light)
        updateDayState { $0.postponed.removeAll { $0 == name } }
        Task { await publishDerivedState() }
    }

    var postponedTasks: [TaskNote] {
        let names = dayState.day == context().today ? dayState.postponed : []
        return names.compactMap(task(named:))
    }

    func setManualOrder(_ names: [String]) {
        updateDayState { $0.manualOrder = names }
        Task { await publishDerivedState() }
    }

    func resetOrder() {
        updateDayState { $0.manualOrder = nil }
        Task { await publishDerivedState() }
    }

    func describe(_ blockers: [Blocker]) -> String {
        L10n.list(blockers.map { blocker in
            switch blocker {
            case .task(let name): name
            case .event(let title, _): title
            }
        })
    }
}
