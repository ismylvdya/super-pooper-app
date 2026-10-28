import Foundation
import Observation

enum VaultState: Equatable {
    case notSelected
    case ready
    case failed(String)
}

/// App-wide state and use cases. Screens read it and call its methods; it talks to repositories
/// and runs the pure domain logic. Split by topic into extensions (`AppModel+…`).
@MainActor
@Observable
final class AppModel {
    let config: AppConfig
    let services: AppServices
    let banners: BannerCenter
    let clock: Clock
    let calendar: Calendar

    private(set) var tasks: [TaskNote] = []
    /// The done folder's tasks, read when the Done list opens (`loadFiledTasks`).
    var filedTasks: [TaskNote] = []
    private(set) var fileProblems: [FileProblem] = []
    private(set) var events: [CalendarEvent] = []
    private(set) var reminders: [ReminderItem] = []
    private(set) var trashedNotes: [TrashedNote] = []
    /// Notes with iCloud conflict versions the user has not resolved yet.
    private(set) var conflictedNotes: [String] = []
    /// The chosen folder is a whole Obsidian vault: the app asks to pick only the TaskNotes folder.
    /// What the chosen folder is (the TaskNotes folder or a whole vault) and where it is in Obsidian.
    var chosenFolder = ChosenFolder()
    var dayState: DayState
    private(set) var vaultState: VaultState = .notSelected
    private(set) var isSyncing = false
    private(set) var hasLoaded = false
    private(set) var settings: AppSettings
    var access = SourceAccessState()
    /// Paths written while a scan was running; their scanned copies are stale.
    @ObservationIgnored private var writtenDuringSync: Set<String>?
    /// Notes trashed or renamed away while a sync runs (its scan may still list them).
    @ObservationIgnored private var removedDuringSync: Set<String>?
    @ObservationIgnored var runningSync: Task<Void, Never>?
    /// Another sync was asked for while one runs (`true`: with the banner).
    @ObservationIgnored var syncAgain: Bool?
    /// The edit of each note still running (see `edit`).
    @ObservationIgnored var pendingEdits: [String: Task<Void, Never>] = [:]
    /// Counts reads of the calendars and reminders; an older read that ends later is dropped.
    @ObservationIgnored var sourcesGeneration = 0
    @ObservationIgnored var notificationTask: Task<Void, Never>?
    @ObservationIgnored var settingsNoteWrite: Task<Void, Never>?
    /// A settings change not written to the vault note yet.
    @ObservationIgnored var settingsNotePending = false

    init(config: AppConfig, services: AppServices, banners: BannerCenter, clock: Clock, calendar: Calendar) {
        self.config = config
        self.services = services
        self.banners = banners
        self.clock = clock
        self.calendar = calendar
        let settings = services.settingsStore.load()
        self.settings = settings
        let today = DayContext(now: clock.now, calendar: calendar, boundary: settings.day.boundary,
                               energyHour: settings.day.energyHour).today
        self.dayState = services.dayStateStore.load(for: today)
    }

    // MARK: - Day

    func context(at date: Date? = nil) -> DayContext {
        DayContext(now: date ?? clock.now, calendar: calendar, boundary: settings.day.boundary, energyHour: settings.day.energyHour)
    }

    func plan(at date: Date, dayOffset: Int) -> DayPlan {
        DayPlanning.plan(config: config, settings: settings, tasks: tasks, events: events, reminders: reminders,
                         dayState: dayState, context: context(at: date), dayOffset: dayOffset, eventsKnown: eventsKnown)
    }

    func plan(at date: Date) -> DayPlan {
        DayPlanning.plan(config: config, settings: settings, tasks: tasks, events: events, reminders: reminders, dayState: dayState,
                         context: context(at: date), eventsKnown: eventsKnown)
    }

    /// Without Calendar access or chosen calendars, a linked event cannot be looked up.
    private var eventsKnown: Bool {
        services.calendars.access == .granted && !settings.sources.anchorCalendarIDs.isEmpty
    }

    func task(named name: String) -> TaskNote? { tasks.first { $0.name == name } }

    var archivedTasks: [TaskNote] {
        NameOrder.sorted(tasks.filter { $0.isArchived && !$0.isHabit })
    }

    func updateDayState(_ change: (inout DayState) -> Void) {
        rollDayIfNeeded()
        change(&dayState)
        try? services.dayStateStore.save(dayState)
    }

    func rollDayIfNeeded() {
        let today = context().today
        guard dayState.day != today else { return }
        dayState = DayState(day: today)
        try? services.dayStateStore.save(dayState)
    }

    // MARK: - Settings

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        let old = settings
        change(&settings)
        guard settings != old else { return }
        try? services.settingsStore.save(settings)
        if SyncedSettings(old) != SyncedSettings(settings) { scheduleSettingsNoteWrite() }
        Task { await settingsDidChange(from: old) }
    }

    /// Settings changed in the vault note (another device, Obsidian) come in without being written back.
    func applySettingsNote(_ json: Data) {
        let old = settings
        let merged = SyncedSettings.merged(note: json, over: settings)
        guard merged != old else { return }
        settings = merged
        try? services.settingsStore.save(settings)
        Task { await settingsDidChange(from: old) }
    }

    /// Writes the vault note shortly after the last change (sliders send many).
    private func scheduleSettingsNoteWrite() {
        settingsNotePending = true
        settingsNoteWrite?.cancel()
        settingsNoteWrite = Task {
            try? await Task.sleep(for: .seconds(config.rules.vault.settingsWriteDelaySeconds))
            guard !Task.isCancelled else { return }
            await writeSettingsNote()
        }
    }

    /// A change not written yet goes to the note before the note is read, so a sync does not undo it.
    func flushSettingsNote() async {
        guard settingsNotePending else { return }
        settingsNoteWrite?.cancel()
        await writeSettingsNote()
    }

    /// A failed write stays pending and is tried again before the next read.
    private func writeSettingsNote() async {
        guard let json = try? JSONEncoder.store.encode(SyncedSettings(settings)) else { return }
        do {
            try await services.settingsNote.write(json)
            settingsNotePending = false
        } catch {
            settingsNotePending = true
        }
    }

    private func settingsDidChange(from old: AppSettings) async {
        if old.sources != settings.sources { await refreshCalendarSources() }
        if old.vault != settings.vault { await sync(announce: false) }
        rollDayIfNeeded()
        await publishDerivedState()
    }

    // MARK: - Internal state updates

    func replace(_ task: TaskNote) {
        if let index = tasks.firstIndex(where: { $0.relativePath == task.relativePath || $0.name == task.name }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
    }

    func remove(_ task: TaskNote) {
        tasks.removeAll { $0.relativePath == task.relativePath }
        removedDuringSync?.insert(task.relativePath)
    }

    /// Notes written while the scan ran keep their in-memory version, and notes created or renamed meanwhile
    /// (the scan had listed the files before them) are kept too.
    func setScanResult(_ result: VaultScanResult) {
        let freshlyWritten = writtenDuringSync ?? []
        let removed = removedDuringSync ?? []
        let scannedPaths = Set(result.tasks.map(\.relativePath))
        let newer = tasks.filter { freshlyWritten.contains($0.relativePath) && !scannedPaths.contains($0.relativePath) }
        tasks = result.tasks.filter { !removed.contains($0.relativePath) }.map { scanned in
            freshlyWritten.contains(scanned.relativePath) ? (tasks.first { $0.relativePath == scanned.relativePath } ?? scanned) : scanned
        } + newer
        fileProblems = result.fileProblems
        conflictedNotes = result.conflicted
        vaultState = .ready
    }

    func beginTrackingWrites() {
        writtenDuringSync = []
        removedDuringSync = []
    }

    func endTrackingWrites() {
        writtenDuringSync = nil
        removedDuringSync = nil
    }
    func noteWrite(_ task: TaskNote) { writtenDuringSync?.insert(task.relativePath) }

    func setVaultState(_ state: VaultState) {
        vaultState = state
        if state != .ready {
            tasks = []
            fileProblems = []
        }
    }

    func setSources(events: [CalendarEvent], reminders: [ReminderItem]) {
        self.events = events
        self.reminders = reminders
    }

    func setSyncing(_ value: Bool) { isSyncing = value }
    func setTrash(_ notes: [TrashedNote]) { trashedNotes = notes }
    func markLoaded() { hasLoaded = true }
}
