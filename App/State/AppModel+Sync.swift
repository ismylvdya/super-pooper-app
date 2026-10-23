import Foundation
import os

extension AppModel {
    /// Full sync: vault, auto-promotion, calendar and reminders, then widgets and notifications.
    /// `announce` shows a banner with what changed (pull-to-refresh).
    /// A second call while a sync runs waits for that sync instead of starting another one.
    func sync(announce: Bool) async {
        if let running = runningSync {
            await running.value
            return
        }
        let task = Task { await performSync(announce: announce) }
        runningSync = task
        await task.value
        runningSync = nil
    }

    private func performSync(announce: Bool) async {
        setSyncing(true)
        defer { setSyncing(false) }
        rollDayIfNeeded()

        let previousTasks = tasks
        var report = SyncReport()
        let started = Date()
        if services.vault.hasVault {
            beginTrackingWrites()
            defer { endTrackingWrites() }
            do {
                let result = try await services.tasks.scan()
                SyncLog.logger.info("vault scan: \(result.tasks.count) tasks in \(Date().timeIntervalSince(started), format: .fixed(precision: 2)) s")
                setScanResult(result)
                vaultIsWholeVault = await services.tasks.isWholeVault()
                report.conflicts = result.conflictsResolved
                if config.flags.autoPromote { report.promoted = await autoPromote() }
            } catch {
                setVaultState(.failed(Self.describe(error)))
            }
        } else {
            setVaultState(.notSelected)
        }
        await refreshCalendarSources()
        SyncLog.logger.info("sources ready after \(Date().timeIntervalSince(started), format: .fixed(precision: 2)) s")

        if hasLoaded {
            let diff = SyncReport(old: previousTasks, new: tasks)
            report.added = diff.added
            report.changed = diff.changed
            report.removed = diff.removed
        }
        markLoaded()
        await publishDerivedState()
        let problems = problemCount
        let newProblems = problems > dayState.announcedProblems
        updateDayState { $0.announcedProblems = problems }
        announceResult(report, announce: announce, newProblems: newProblems)
    }

    func ensureLoaded() async {
        if !hasLoaded { await sync(announce: false) }
    }

    /// Re-reads anchor events and reminders (cheap, no vault access).
    func refreshCalendarSources() async {
        let context = context()
        let rules = config.rules
        let from = context.today.adding(days: -rules.eventLinks.resolveDaysBefore).startDate(in: calendar)
        let to = context.today.adding(days: rules.eventLinks.resolveDaysAfter + 1).startDate(in: calendar)
        let events = services.calendars.events(from: from, to: to, calendarIDs: settings.sources.anchorCalendarIDs)
        var reminders: [ReminderItem] = []
        if config.flags.reminders {
            let until = context.today.adding(days: rules.notifications.horizonDays).startDate(in: calendar, offset: settings.day.boundary)
            reminders = await services.reminders.reminders(from: context.dayStart, to: until, listIDs: settings.sources.reminderListIDs)
        }
        setSources(events: events, reminders: reminders)
    }

    /// Widgets snapshot, widget reload and notification schedule follow every change.
    func publishDerivedState() async {
        let context = context()
        if config.flags.widgetSnapshot {
            let snapshot = WidgetSnapshot(generatedAt: context.now, tasks: tasks, events: events,
                                          reminders: reminders.filter { context.contains($0.due) }, dayState: dayState)
            try? services.snapshotStore.save(snapshot)
        }
        services.widgets.reloadAll()
        // The notification center can be slow to answer (or not answer at all in a broken simulator);
        // a sync never waits for it. The newest plan replaces one still being scheduled.
        notificationTask?.cancel()
        notificationTask = Task { await rescheduleNotifications(context: context) }
    }

    /// Background refresh waits for the notification schedule before the app is suspended.
    func waitForNotifications() async {
        await notificationTask?.value
    }

    func rescheduleNotifications(context: DayContext) async {
        guard config.flags.notifications, settings.notifications.enabled else {
            await services.notifications.removeAll()
            return
        }
        let rules = config.rules.notifications
        let planner = NotificationPlanner(horizonDays: rules.horizonDays, limit: rules.limit)
        let skipped = Set(dayState.day == context.today ? dayState.skipped : [])
        let planned = planner.plan(tasks: tasks, reminders: reminders, skipped: skipped, context: context)
        let valid = planner.stillValidToday(tasks: tasks, reminders: reminders, skipped: skipped, context: context)
        await services.notifications.sync(planned: planned, stillValid: valid)
    }

    var problemCount: Int { fileProblems.count + plan(at: clock.now).problems.count }

    private func autoPromote() async -> [String] {
        let statuses = Set(config.rules.day.autoPromoteFrom.map(config.fieldMapping.status(fromRaw:)))
        let candidates = AutoPromoter(promotableStatuses: statuses).candidates(in: tasks, context: context())
        guard !candidates.isEmpty else { return [] }
        if config.flags.backups { try? await services.tasks.backup(candidates, reason: "auto-promote") }
        var promoted: [String] = []
        for task in candidates {
            guard let result = try? await services.tasks.apply([.status(.thisWeek)], to: task) else { continue }
            replace(result.task)
            promoted.append(task.name)
        }
        return promoted
    }

    private func announceResult(_ report: SyncReport, announce: Bool, newProblems: Bool) {
        for name in report.conflicts {
            banners.show(L10n.format("banner.conflict", name), style: .warning)
        }
        if !report.promoted.isEmpty {
            banners.show(L10n.format("banner.promoted", L10n.list(report.promoted)), style: .success)
        }
        if announce, config.flags.syncBanner {
            banners.show(report.summary, style: .synced)
        }
        if newProblems, config.flags.problemBadge {
            banners.show(L10n.format("banner.problems", problemCount), style: .problem)
        }
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case VaultAccessError.notSelected: L10n.string("error.vault.notSelected")
        case VaultAccessError.bookmarkInvalid: L10n.string("error.vault.bookmark")
        case VaultAccessError.accessDenied: L10n.string("error.vault.access")
        case TaskRepositoryError.nameTaken(let name): L10n.format("error.rename.taken", name)
        case TaskRepositoryError.invalidName(let name): L10n.format("error.rename.invalid", name)
        case TaskRepositoryError.fileMissing(let name): L10n.format("error.file.missing", name)
        default: error.localizedDescription
        }
    }
}

extension AppModel {
    func selectVault(_ url: URL) async {
        SyncLog.logger.info("vault selected: \(url.path, privacy: .public)")
        do {
            try services.vault.select(url)
            await sync(announce: true)
            if vaultIsWholeVault { banners.show(L10n.string("banner.wholeVault"), style: .warning) }
        } catch {
            SyncLog.logger.error("vault selection failed: \(String(describing: error), privacy: .public)")
            banners.show(Self.describe(error), style: .problem)
        }
    }
}

enum SyncLog {
    static let logger = Logger(subsystem: "SuperPooper", category: "sync")
}
