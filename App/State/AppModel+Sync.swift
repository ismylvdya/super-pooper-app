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
        var scanFailed = false
        let started = Date()
        if services.vault.hasVault {
            beginTrackingWrites()
            defer { endTrackingWrites() }
            do {
                let result = try await services.tasks.scan()
                SyncLog.logger.info("vault scan: \(result.tasks.count) tasks in \(Date().timeIntervalSince(started), format: .fixed(precision: 2)) s")
                setScanResult(result)
                vaultIsWholeVault = await services.tasks.isWholeVault()
                // The vault's settings note wins over this device (after this device's unwritten change went
                // there); the first time, this device writes it.
                await flushSettingsNote()
                if let json = await services.settingsNote.read() {
                    applySettingsNote(json)
                } else if let json = try? JSONEncoder.store.encode(SyncedSettings(settings)) {
                    try? await services.settingsNote.write(json)
                }
                report.conflicts = result.conflicted
                if config.flags.autoPromote { report.promoted = await autoPromote() }
            } catch {
                setVaultState(.failed(Self.describe(error)))
                scanFailed = true
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
        // A vault that could not be read this time leaves the notifications and the widgets as they were.
        if !scanFailed { await publishDerivedState() }
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
            // Past days too, for browsing them on Today.
            let from = context.today.adding(days: -rules.eventLinks.resolveDaysBefore).startDate(in: calendar, offset: settings.day.boundary)
            reminders = await services.reminders.reminders(from: from, to: until, listIDs: settings.sources.reminderListIDs)
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
        // Skip today (habits) and Not today (tasks) both take an item out of today's notifications.
        let skipped = Set(dayState.day == context.today ? dayState.skipped + dayState.postponed : [])
        let planned = planner.plan(tasks: tasks, reminders: reminders, events: events, skipped: skipped, context: context)
        let valid = planner.stillValidToday(tasks: tasks, reminders: reminders, events: events, skipped: skipped, context: context)
        // Alerts moved into the past or added too late come right away, once.
        let all = planner.all(tasks: tasks, reminders: reminders, events: events, skipped: skipped, context: context)
        let previous = services.alertStateStore.load()
        let late = LateAlerts.due(all, pending: previous?.pending ?? [:], known: previous.map { Set($0.known) },
                                  now: context.now, calendar: calendar)
        try? services.alertStateStore.save(AlertState(
            pending: Dictionary(planned.map { ($0.key, $0.fireDate) }, uniquingKeysWith: min),
            known: Array(Set(all.map(\.key)))))
        await services.notifications.sync(planned: planned, stillValid: valid + late, now: late)
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
        if !report.conflicts.isEmpty {
            banners.show(L10n.format("banner.conflict", L10n.list(report.conflicts)), style: .warning, opens: .conflicts)
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
        // System errors would come in the phone's language; the app speaks English.
        default: L10n.format("error.generic", (error as NSError).domain, (error as NSError).code)
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
