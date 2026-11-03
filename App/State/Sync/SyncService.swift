import Foundation
import Observation
import os

/// The full sync and what a change of the settings or of the time brings: the tasks read again, the vault's settings
/// note, auto-promotion, done tasks filed away, the calendars and reminders, then the widgets and the notifications.
@MainActor
@Observable
final class SyncService: SettingsObserver {
    private(set) var hasLoaded = false
    private(set) var isSyncing = false
    @ObservationIgnored private let config: AppConfig
    @ObservationIgnored private let services: AppServices
    @ObservationIgnored private let tasks: TaskState
    @ObservationIgnored private let settings: SettingsController
    @ObservationIgnored private let day: DayStateController
    @ObservationIgnored private let sources: SourcesController
    @ObservationIgnored private let writer: NoteWriter
    @ObservationIgnored private let texts: NoteTextEditor
    @ObservationIgnored private let derived: DerivedStatePublisher
    @ObservationIgnored private let backups: BackupPolicy
    @ObservationIgnored private let appEvents: AppEventSink
    @ObservationIgnored private var running: Task<Void, Never>?
    /// Another sync was asked for while one runs (`true`: with the banner).
    @ObservationIgnored private var again: Bool?

    init(config: AppConfig, services: AppServices, tasks: TaskState, settings: SettingsController, day: DayStateController,
         sources: SourcesController, writer: NoteWriter, texts: NoteTextEditor, derived: DerivedStatePublisher,
         backups: BackupPolicy, appEvents: AppEventSink) {
        self.config = config
        self.services = services
        self.tasks = tasks
        self.settings = settings
        self.day = day
        self.sources = sources
        self.writer = writer
        self.texts = texts
        self.derived = derived
        self.backups = backups
        self.appEvents = appEvents
    }

    /// Another sync waits for the running one.
    var isSyncQueued: Bool { again != nil }

    /// A vault folder is chosen (it may still be loading).
    var hasVault: Bool { services.vault.hasVault }
    var vaultName: String? { services.vault.displayName }

    /// `announce` reports what changed (pull-to-refresh). A call while a sync runs does not start a second one in
    /// parallel: the running sync reads everything once more when it is done (the vault or settings may have changed
    /// since it started), and the call waits for that.
    func sync(announce: Bool) async {
        if let running {
            again = (again ?? false) || announce
            await running.value
            return
        }
        let task = Task {
            var next: Bool? = announce
            while let current = next {
                again = nil
                await performSync(announce: current)
                next = again
            }
        }
        running = task
        await task.value
        running = nil
    }

    func ensureLoaded() async {
        if !hasLoaded { await sync(announce: false) }
    }

    /// While the app stays open over the end of the logical day, the new day is read and published right then: the day
    /// that is over takes its notifications with it, the widgets turn the page.
    func syncWhenTheDayEnds() async {
        let wait = day.context().dayEnd.timeIntervalSince(day.clock.now)
        guard wait > 0 else { return }
        try? await Task.sleep(for: .seconds(wait))
        guard !Task.isCancelled else { return }
        await sync(announce: false)
    }

    /// The phone moved to another time zone or its clock jumped: the day is worked out again in the calendar as it is
    /// now, and the widgets and the notifications follow (a full sync, as at launch).
    func timeDidChange() async {
        day.refreshCalendar()
        await sync(announce: false)
    }

    func importTaskNotes(from folder: URL) async -> Int? {
        guard let read = services.readTaskNotes, let importer = services.importer else { return nil }
        do {
            let count = try await importer.importItems(try await read(folder))
            await sync(announce: true)
            return count
        } catch {
            appEvents.send(.failure(AppFailure(error)))
            return nil
        }
    }

    func selectVault(_ url: URL) async {
        SyncLog.logger.info("vault selected: \(url.path, privacy: .public)")
        do {
            try services.vault.select(url)
            await sync(announce: true)
            if tasks.chosenFolder.isWholeVault { appEvents.send(.wholeVaultChosen) }
        } catch {
            SyncLog.logger.error("vault selection failed: \(String(describing: error), privacy: .public)")
            appEvents.send(.failure(AppFailure(error)))
        }
    }

    /// Other calendars or lists are read again, another folder synced; the notifications and the widget snapshot are
    /// planned again only when the change moves the day or what is in it. Anything else only changes how things look,
    /// and the widgets read that from the settings themselves.
    func settingsDidChange(from old: AppSettings) async {
        let new = settings.settings
        if old.sources != new.sources { await sources.refresh() }
        if old.vault != new.vault { await sync(announce: false) }
        day.rollDayIfNeeded()
        if new.replansDay(comparedTo: old) {
            await derived.publish()
        } else {
            derived.reloadWidgets()
        }
    }

    private func performSync(announce: Bool) async {
        isSyncing = true
        defer { isSyncing = false }
        // The scan and the calendars read the folder and the lists from the settings file.
        settings.writeWaiting()
        day.rollDayIfNeeded()

        let previousTasks = tasks.tasks
        var report = SyncReport()
        var scanFailed = false
        let started = Date()
        if services.vault.hasVault {
            tasks.beginTrackingWrites()
            defer { tasks.endTrackingWrites() }
            do {
                let result = try await services.tasks.load()
                SyncLog.logger.info("vault scan: \(result.tasks.count) tasks in \(Date().timeIntervalSince(started), format: .fixed(precision: 2)) s")
                tasks.setScanResult(result)
                if let folder = services.folder { tasks.setChosenFolder(await folder.chosenFolder()) }
                await settings.syncWithVaultNote()
                report.conflicts = result.conflicted
                if config.flags.autoPromote { report.promoted = await autoPromote() }
                await writer.fileAwayDoneTasks()
            } catch {
                tasks.setVaultState(.failed(AppFailure(error)))
                scanFailed = true
            }
        } else {
            tasks.setVaultState(.notSelected)
        }
        await sources.refresh()
        SyncLog.logger.info("sources ready after \(Date().timeIntervalSince(started), format: .fixed(precision: 2)) s")

        if hasLoaded {
            let diff = SyncReport(old: previousTasks, new: tasks.tasks)
            report.added = diff.added
            report.changed = diff.changed
            report.removed = diff.removed
        }
        hasLoaded = true
        // A vault that could not be read this time leaves the notifications and the widgets as they were.
        if !scanFailed { await derived.publish() }
        let problems = derived.problemCount
        tell(report, announce: announce, newProblems: day.announceProblems(problems), problems: problems)
        await texts.reopenUnavailable()
    }

    /// Decided on the day's view (times on the phone's clock), written to the notes as they are.
    private func autoPromote() async -> [String] {
        let statuses = Set(config.rules.day.autoPromoteFrom.map(\.status))
        let candidates = AutoPromoter(promotableStatuses: statuses).candidates(in: day.local(tasks.tasks), context: day.context())
            .compactMap { tasks.task(named: $0.name) }
        guard !candidates.isEmpty else { return [] }
        try? await backups.backup(candidates, reason: "auto-promote")
        var promoted: [String] = []
        let marking = TaskMarking(today: day.context().today)
        for task in candidates {
            guard let result = try? await services.tasks.apply(marking.changes(setting: .thisWeek, on: task), to: task) else { continue }
            tasks.replace(result.task)
            promoted.append(task.name)
        }
        return promoted
    }

    private func tell(_ report: SyncReport, announce: Bool, newProblems: Bool, problems: Int) {
        if !report.conflicts.isEmpty { appEvents.send(.conflictsFound(report.conflicts)) }
        if !report.promoted.isEmpty { appEvents.send(.promoted(report.promoted)) }
        if announce, config.flags.syncBanner {
            appEvents.send(.synced(added: report.added.count, changed: report.changed.count, removed: report.removed.count))
        }
        if newProblems, config.flags.problemBadge { appEvents.send(.problemsFound(problems)) }
    }
}
