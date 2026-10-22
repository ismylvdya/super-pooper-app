import Foundation

extension AppModel {
    /// Tap on a task: check it off or un-check it. Blocked tasks only explain what holds them.
    func toggle(_ name: String) async {
        guard let task = task(named: name) else { return }
        if let item = plan(at: clock.now).item(named: name), item.isBlocked {
            banners.show(L10n.format("banner.blocked", describe(item.blockers)), style: .problem)
            return
        }
        await write(task, TaskMarking(today: context().today).changes(toggling: task))
    }

    func perform(_ action: ActionID, on name: String) async {
        guard let task = task(named: name) else { return }
        let marking = TaskMarking(today: context().today)
        switch action {
        case .done, .partial, .twice:
            if let item = plan(at: clock.now).item(named: name), item.isBlocked {
                banners.show(L10n.format("banner.blocked", describe(item.blockers)), style: .problem)
                return
            }
            let mark: HabitMark = action == .partial ? .partial : action == .twice ? .twice : .done
            await write(task, marking.changes(marking: task, as: mark))
        case .unmark:
            await write(task, marking.changes(marking: task, as: nil))
        case .skipToday:
            updateDayState { if !$0.skipped.contains(name) { $0.skipped.append(name) } }
            await publishDerivedState()
        case .archive:
            await write(task, [.status(.archived)])
            banners.show(L10n.format("banner.archived", name), style: .success)
        case .restoreThisWeek:
            await write(task, [.status(.thisWeek)])
        case .restoreHalfYear:
            await write(task, [.status(.halfYear)])
        case .delete:
            await delete(task)
        case .open, .openInObsidian:
            break
        }
    }

    func update(_ name: String, _ changes: [TaskFieldChange]) async {
        guard let task = task(named: name) else { return }
        await write(task, changes)
    }

    func write(_ task: TaskNote, _ changes: [TaskFieldChange]) async {
        guard !changes.isEmpty else { return }
        do {
            let result = try await services.tasks.apply(changes, to: task)
            replace(result.task)
            if result.hadConflict { banners.show(L10n.format("banner.conflict", task.name), style: .problem) }
            await publishDerivedState()
        } catch {
            banners.show(Self.describe(error), style: .problem)
        }
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

    /// Renames the note file; tasks that link to it get their `previous_task` updated.
    @discardableResult
    func rename(_ name: String, to newName: String) async -> Bool {
        guard let task = task(named: name) else { return false }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != name else { return true }
        let dependents = tasks.filter { $0.previousTasks.contains { $0.lowercased() == name.lowercased() } }
        do {
            if config.flags.backups { try await services.tasks.backup([task] + dependents, reason: "rename") }
            _ = try await services.tasks.rename(task, to: trimmed, dependents: dependents)
            let result = try await services.tasks.scan()
            setScanResult(result)
            await publishDerivedState()
            return true
        } catch {
            banners.show(Self.describe(error), style: .problem)
            return false
        }
    }

    func body(of name: String) async -> String? {
        guard let task = task(named: name) else { return nil }
        return try? await services.tasks.body(of: task)
    }

    func setBody(_ body: String, of name: String) async {
        guard let task = task(named: name) else { return }
        do {
            let result = try await services.tasks.setBody(body, of: task)
            replace(result.task)
            if result.hadConflict { banners.show(L10n.format("banner.conflict", task.name), style: .problem) }
        } catch {
            banners.show(Self.describe(error), style: .problem)
        }
    }

    func obsidianURL(for name: String) async -> URL? {
        guard let task = task(named: name) else { return nil }
        return await services.tasks.obsidianURL(for: task)
    }

    // MARK: - Pool order

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
