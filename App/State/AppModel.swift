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
    /// The wait of debounced work (note text, Calendar changes); tests end it themselves.
    let delay: Delay
    /// Where the calendar comes from; `calendar` is its copy the screens observe, renewed by `timeDidChange`.
    let calendarSource: CalendarSource
    private(set) var calendar: Calendar

    private(set) var tasks: [TaskItem] = []
    /// The done folder's tasks, read when the Lists tab or the Done list shows (`loadFiledTasks`).
    var filedTasks: [TaskItem] = []
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
    /// The text of the notes open on their pages (see `openBody`).
    var noteBodies: [String: NoteBody] = [:]
    /// The write of each note's text waiting for typing to stop, and the writes running (one after another per note).
    @ObservationIgnored var noteBodyDebounce: [String: Task<Void, Never>] = [:]
    @ObservationIgnored var noteBodySaves: [String: Task<Void, Never>] = [:]
    /// Notes written while a scan was running; their scanned copies are stale.
    @ObservationIgnored private var writtenDuringSync: Set<TaskID>?
    /// Notes trashed or renamed away while a sync runs (its scan may still list them).
    @ObservationIgnored private var removedDuringSync: Set<TaskID>?
    @ObservationIgnored var runningSync: Task<Void, Never>?
    /// Another sync was asked for while one runs (`true`: with the banner).
    @ObservationIgnored var syncAgain: Bool?
    /// The edit of each note still running (see `edit`).
    @ObservationIgnored var pendingEdits: [String: Task<Void, Never>] = [:]
    /// Counts reads of the calendars and reminders; an older read that ends later is dropped.
    @ObservationIgnored var sourcesGeneration = 0
    @ObservationIgnored var notificationTask: Task<Void, Never>?
    /// The read of Calendar and Reminders waiting for a burst of changes to end, and the loops that hear the changes.
    @ObservationIgnored var sourcesRefresh: Task<Void, Never>?
    @ObservationIgnored var sourceObservers: [Task<Void, Never>] = []
    @ObservationIgnored var settingsNoteWrite: Task<Void, Never>?
    /// A settings change not written to the vault note yet.
    @ObservationIgnored var settingsNotePending = false
    /// The settings file write and what the change brings, waiting for the changes to stop.
    @ObservationIgnored var settingsSave: Task<Void, Never>?
    /// The settings before the changes still waiting there; nil when nothing waits.
    @ObservationIgnored var settingsBeforeSave: AppSettings?
    /// The last plan of each day asked for (0 = today), with what it was worked out from (`AppModel+Plan`).
    @ObservationIgnored var plans: [Int: CachedPlan] = [:]

    init(config: AppConfig, services: AppServices, banners: BannerCenter, clock: Clock, calendar: CalendarSource,
         delay: Delay = SleepDelay()) {
        self.config = config
        self.services = services
        self.banners = banners
        self.clock = clock
        self.delay = delay
        self.calendarSource = calendar
        let calendar = calendar.current
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

    /// The phone moved to another time zone or its clock jumped: the day is worked out again in the calendar as it is
    /// now, and the widgets and the notifications follow (a full sync, as at launch).
    func timeDidChange() async {
        calendar = calendarSource.current
        await sync(announce: false)
    }

    func task(named name: String) -> TaskItem? { tasks.first { $0.name.isSameNoteName(as: name) } }

    /// The tasks as the day sees them: times kept in a zone of their own moved to the phone's clock (`ZonedTimes`). Logic
    /// that decides from times works on these; what it decides is written back with `writeLocal` / `setLocalDue`.
    var localTasks: [TaskItem] {
        let context = context()
        return ZonedTimes.local(tasks, calendar: context.calendar, today: context.today)
    }

    func localTask(named name: String) -> TaskItem? {
        let context = context()
        return task(named: name).map { ZonedTimes.local($0, calendar: context.calendar, today: context.today) }
    }

    /// The tasks that wait for `name`, by name: its Next tasks.
    func nextTasks(of name: String) -> [String] {
        NameOrder.sorted(NameReferences.waiting(for: name, in: tasks).map(\.name))
    }

    var archivedTasks: [TaskItem] {
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

    /// The screens see a change at once. The file is written, and what the change brings is worked out, once the changes
    /// stop (a slider sends one per step): see `settingsDidChange`.
    func updateSettings(_ change: (inout AppSettings) -> Void) {
        let old = settings
        change(&settings)
        guard settings != old else { return }
        if SyncedSettings(old) != SyncedSettings(settings) { scheduleSettingsNoteWrite() }
        scheduleSettingsSave(from: old)
    }

    private func scheduleSettingsSave(from old: AppSettings) {
        if settingsBeforeSave == nil { settingsBeforeSave = old }
        settingsSave?.cancel()
        settingsSave = Task {
            try? await delay.wait(config.rules.editing.settingsSaveDelaySeconds)
            guard !Task.isCancelled else { return }
            await saveSettings()
        }
    }

    /// A change still waiting is written and followed now (the app goes to the background).
    func flushSettings() async {
        guard settingsBeforeSave != nil else { return }
        settingsSave?.cancel()
        await saveSettings()
    }

    /// The file only, for a sync that reads the folder and the calendars from it; the rest follows after the wait.
    func writeWaitingSettings() {
        guard settingsBeforeSave != nil else { return }
        try? services.settingsStore.save(settings)
    }

    private func saveSettings() async {
        guard let old = settingsBeforeSave else { return }
        settingsBeforeSave = nil
        try? services.settingsStore.save(settings)
        await settingsDidChange(from: old)
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
            try? await delay.wait(config.rules.vault.settingsWriteDelaySeconds)
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

    /// Other calendars or lists are read again, another folder synced; the notifications and the widget snapshot are
    /// planned again only when the change moves the day or what is in it. Anything else only changes how things look,
    /// and the widgets read that from the settings themselves.
    private func settingsDidChange(from old: AppSettings) async {
        if old.sources != settings.sources { await refreshCalendarSources() }
        if old.vault != settings.vault { await sync(announce: false) }
        rollDayIfNeeded()
        if settings.replansDay(comparedTo: old) {
            await publishDerivedState()
        } else {
            services.widgets.reloadAll()
        }
    }

    // MARK: - Internal state updates

    func replace(_ task: TaskItem) {
        if let index = tasks.firstIndex(where: { $0.id == task.id || $0.name == task.name }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
    }

    func remove(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
        removedDuringSync?.insert(task.id)
    }

    /// Notes written while the scan ran keep their in-memory version, and notes created or renamed meanwhile
    /// (the scan had listed the files before them) are kept too.
    func setScanResult(_ result: VaultScanResult) {
        let freshlyWritten = writtenDuringSync ?? []
        let removed = removedDuringSync ?? []
        let scanned = Set(result.tasks.map(\.id))
        let newer = tasks.filter { freshlyWritten.contains($0.id) && !scanned.contains($0.id) }
        tasks = result.tasks.filter { !removed.contains($0.id) }.map { scanned in
            freshlyWritten.contains(scanned.id) ? (tasks.first { $0.id == scanned.id } ?? scanned) : scanned
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
    func noteWrite(_ task: TaskItem) { writtenDuringSync?.insert(task.id) }

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
