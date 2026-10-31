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

    private func performSync(announce: Bool) async {
        setSyncing(true)
        defer { setSyncing(false) }
        // The scan and the calendars read the folder and the lists from the settings file.
        writeWaitingSettings()
        rollDayIfNeeded()

        let previousTasks = tasks
        var report = SyncReport()
        var scanFailed = false
        let started = Date()
        if services.vault.hasVault {
            beginTrackingWrites()
            defer { endTrackingWrites() }
            do {
                let result = try await services.tasks.load()
                SyncLog.logger.info("vault scan: \(result.tasks.count) tasks in \(Date().timeIntervalSince(started), format: .fixed(precision: 2)) s")
                setScanResult(result)
                if let folder = services.folder { chosenFolder = await folder.chosenFolder() }
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
                await fileAwayDoneTasks()
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
        await reopenUnavailableBodies()
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
        let events = await services.calendars.events(from: from, to: to, calendarIDs: settings.sources.anchorCalendarIDs)
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

    private func autoPromote() async -> [String] {
        let statuses = Set(config.rules.day.autoPromoteFrom.map(\.status))
        // Decided on the day's view (times on the phone's clock), written to the notes as they are.
        let candidates = AutoPromoter(promotableStatuses: statuses).candidates(in: localTasks, context: context())
            .compactMap { task(named: $0.name) }
        guard !candidates.isEmpty else { return [] }
        try? await backup(candidates, reason: "auto-promote")
        var promoted: [String] = []
        let marking = TaskMarking(today: context().today)
        for task in candidates {
            guard let result = try? await services.tasks.apply(marking.changes(setting: .thisWeek, on: task), to: task) else { continue }
            replace(result.task)
            promoted.append(task.name)
        }
        return promoted
    }

    private func announceResult(_ report: SyncReport, announce: Bool, newProblems: Bool) {
        if !report.conflicts.isEmpty {
            banners.show(L10n.string("banner.conflict"), style: .warning, opens: .conflicts, items: report.conflicts)
        }
        if !report.promoted.isEmpty {
            banners.show(L10n.string("banner.promoted"), style: .success, items: report.promoted)
        }
        if announce, config.flags.syncBanner {
            banners.show(report.summary, style: .synced, counts: report.counts)
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
        case TaskStoreError.nameTaken(let name): L10n.format("error.rename.taken", name)
        case TaskStoreError.invalidName(let name): L10n.format("error.rename.invalid", name)
        case TaskStoreError.fileMissing(let name): L10n.format("error.file.missing", name)
        case TaskStoreError.notConfirmed(let name): L10n.format("error.write.notConfirmed", name)
        case CalendarEditError.eventNotFound: L10n.string("error.event.notFound")
        case ReminderEditError.reminderNotFound: L10n.string("error.reminder.notFound")
        // System errors would come in the phone's language; the app speaks English.
        default: L10n.format("error.generic", (error as NSError).domain, (error as NSError).code)
        }
    }
}
