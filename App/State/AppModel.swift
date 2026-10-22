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
    private(set) var fileProblems: [FileProblem] = []
    private(set) var events: [CalendarEvent] = []
    private(set) var reminders: [ReminderItem] = []
    var dayState: DayState
    private(set) var vaultState: VaultState = .notSelected
    private(set) var isSyncing = false
    private(set) var hasLoaded = false
    private(set) var settings: AppSettings
    var access = SourceAccessState()
    /// Paths written while a scan was running; their scanned copies are stale.
    @ObservationIgnored private var writtenDuringSync: Set<String>?
    @ObservationIgnored var runningSync: Task<Void, Never>?

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

    func plan(at date: Date) -> DayPlan {
        DayPlanning.plan(config: config, tasks: tasks, events: events, reminders: reminders, dayState: dayState,
                         context: context(at: date))
    }

    func task(named name: String) -> TaskNote? { tasks.first { $0.name == name } }

    var archivedTasks: [TaskNote] {
        tasks.filter { $0.status == .archived }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
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
        Task { await settingsDidChange(from: old) }
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
    }

    func setScanResult(_ result: VaultScanResult) {
        let freshlyWritten = writtenDuringSync ?? []
        tasks = result.tasks.map { scanned in
            freshlyWritten.contains(scanned.relativePath) ? (tasks.first { $0.relativePath == scanned.relativePath } ?? scanned) : scanned
        }
        fileProblems = result.fileProblems
        vaultState = .ready
    }

    func beginTrackingWrites() { writtenDuringSync = [] }
    func endTrackingWrites() { writtenDuringSync = nil }
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
    func markLoaded() { hasLoaded = true }
}
