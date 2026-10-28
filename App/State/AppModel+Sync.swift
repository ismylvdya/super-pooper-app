import Foundation
import os

extension AppModel {
    /// Full sync: vault, auto-promotion, calendar and reminders, then widgets and notifications.
    /// `announce` shows a banner with what changed (pull-to-refresh).
    /// A call while a sync runs does not start a second one in parallel: the running sync reads everything once
    /// more when it is done (the vault or settings may have changed since it started), and the call waits for that.
    func sync(announce: Bool) async {
        if let running = runningSync {
            syncAgain = (syncAgain ?? false) || announce
            await running.value
            return
        }
        let task = Task {
            var next: Bool? = announce
            while let current = next {
                syncAgain = nil
                await performSync(announce: current)
                next = syncAgain
            }
        }
        runningSync = task
        await task.value
        runningSync = nil
    }

    /// While the app stays open over the end of the logical day, the new day is read and published right then:
    /// the day that is over takes its notifications with it, the widgets turn the page.
    func syncWhenTheDayEnds() async {
        let wait = context().dayEnd.timeIntervalSince(clock.now)
        guard wait > 0 else { return }
        try? await Task.sleep(for: .seconds(wait))
        guard !Task.isCancelled else { return }
        await sync(announce: false)
    }

    /// Notes of an older format (separate setting keys, the old settings property, `need_energy`/`pleasant`) are
    /// rewritten into the current fields once; no value changes.
    private func migrateLegacyFields() async {
        for task in tasks where task.hasLegacyFields {
            await edit(task.name) { _ in [.migrateLegacyFields] }
        }
    }

    /// Done tasks of earlier days go to the done folder; the tasks that waited for them lose those met links first.
    private func fileAwayDoneTasks() async {
        for task in DoneFiling.due(tasks, today: context().today) {
            for dependent in DoneFiling.unlinking(task.name, from: tasks) {
                await edit(dependent.name) { _ in [.removePreviousTask(task.name)] }
            }
            do {
                if config.flags.backups { try await services.tasks.backup([task], reason: "done") }
                try await services.tasks.fileAway(task)
                remove(task)
            } catch {
                SyncLog.logger.error("filing \(task.name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
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
                chosenFolder = await services.tasks.chosenFolder()
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
                await migrateLegacyFields()
                if config.flags.fileDoneTasks { await fileAwayDoneTasks() }
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

    /// Re-reads anchor events and reminders (cheap, no vault access). Reads can overlap (settings changed,
    /// Calendar changed, a sync); only the newest one is kept.
    func refreshCalendarSources() async {
        sourcesGeneration += 1
        let generation = sourcesGeneration
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
        guard generation == sourcesGeneration else { return }
        setSources(events: events, reminders: reminders)
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
        case TaskRepositoryError.notConfirmed(let name): L10n.format("error.write.notConfirmed", name)
        // System errors would come in the phone's language; the app speaks English.
        default: L10n.format("error.generic", (error as NSError).domain, (error as NSError).code)
        }
    }
}
