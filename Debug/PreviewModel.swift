#if DEBUG
import SwiftUI

/// An app model on in-memory sample data for SwiftUI previews of whole screens.
@MainActor
enum PreviewModel {
    static func make() -> (model: AppModel, router: Router, config: AppConfig)? {
        guard let config = try? AppConfig.load() else { return nil }
        let store = JSONFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("SuperPooperPreview"))
        let services = AppServices(
            vault: FixedVaultLocation(url: store.directory), tasks: InMemoryTaskRepository(tasks: PreviewSamples.tasks),
            calendars: StaticCalendarRepository(), reminders: StaticRemindersRepository(), notifications: SilentNotifications(),
            settingsStore: SettingsStore(store: store, defaults: config.defaultSettings), dayStateStore: DayStateStore(store: store),
            snapshotStore: SnapshotStore(store: store), widgets: NoWidgets())
        let model = AppModel(config: config, services: services, banners: BannerCenter(),
                             clock: FixedClock(now: PreviewSamples.context.now), calendar: PreviewSamples.calendar)
        model.setScanResult(VaultScanResult(tasks: PreviewSamples.tasks, fileProblems: [], conflictsResolved: []))
        model.setSources(events: PreviewSamples.events, reminders: PreviewSamples.reminders)
        return (model, Router(), config)
    }
}

extension View {
    /// Wraps a screen with the preview app model and configs.
    @MainActor
    func previewEnvironment() -> some View {
        Group {
            if let preview = PreviewModel.make() {
                NavigationStack { self }
                    .environment(preview.model)
                    .environment(preview.router)
                    .environment(preview.model.banners)
                    .appConfig(preview.config)
            } else {
                Text(verbatim: "Config error")
            }
        }
    }
}

actor InMemoryTaskRepository: TaskRepository {
    private var tasks: [TaskNote]
    private var bodies: [String: String] = [:]

    init(tasks: [TaskNote]) { self.tasks = tasks }

    func scan() async throws -> VaultScanResult { VaultScanResult(tasks: tasks, fileProblems: [], conflictsResolved: []) }

    func apply(_ changes: [TaskFieldChange], to task: TaskNote) async throws -> TaskWriteResult {
        let updated = task.applying(changes)
        tasks = tasks.map { $0.name == task.name ? updated : $0 }
        return TaskWriteResult(task: updated, hadConflict: false)
    }

    func body(of task: TaskNote) async throws -> String { bodies[task.name] ?? "Заметка к задаче." }

    func setBody(_ body: String, of task: TaskNote) async throws -> TaskWriteResult {
        bodies[task.name] = body
        return TaskWriteResult(task: task, hadConflict: false)
    }

    func rename(_ task: TaskNote, to newName: String, dependents: [TaskNote]) async throws -> TaskNote {
        var renamed = task
        renamed.name = newName
        tasks = tasks.map { $0.name == task.name ? renamed : $0 }
        return renamed
    }

    func moveToTrash(_ task: TaskNote) async throws { tasks.removeAll { $0.name == task.name } }
    func backup(_ tasks: [TaskNote], reason: String) async throws {}
    func obsidianURL(for task: TaskNote) async -> URL? { nil }
}

struct StaticCalendarRepository: CalendarRepository {
    var access: SourceAccess { .granted }
    func requestAccess() async -> Bool { true }
    func calendars() -> [SourceCollection] { [SourceCollection(id: "demo", title: "Demo", colorHex: "#30B0C7", sourceTitle: "iCloud")] }
    func events(from start: Date, to end: Date, calendarIDs: [String]) -> [CalendarEvent] { PreviewSamples.events }
}

struct StaticRemindersRepository: RemindersRepository {
    var access: SourceAccess { .granted }
    func requestAccess() async -> Bool { true }
    func lists() -> [SourceCollection] { [SourceCollection(id: "list", title: "Remember", colorHex: "#FF9500", sourceTitle: "iCloud")] }
    func reminders(from start: Date, to end: Date, listIDs: [String]) async -> [ReminderItem] { PreviewSamples.reminders }
}

struct SilentNotifications: NotificationScheduling {
    func access() async -> SourceAccess { .granted }
    func requestAccess() async -> Bool { true }
    func registerCategories(_ registry: ActionRegistry, habitActionsEnabled: Bool) {}
    func sync(planned: [PlannedNotification], stillValid: [PlannedNotification]) async {}
    func removeAll() async {}
}

struct NoWidgets: WidgetReloading {
    func reloadAll() {}
}

#Preview("Today") { TodayScreen().previewEnvironment() }
#Preview("Task page") { TaskPageScreen(taskName: "Сдать отчёт").previewEnvironment() }
#Preview("Habit page") { TaskPageScreen(taskName: "Выпить воды 💧").previewEnvironment() }
#Preview("Morning review") { MorningReviewScreen().previewEnvironment() }
#Preview("Settings") { SettingsScreen().previewEnvironment() }
#Preview("Archive") { ArchiveScreen().previewEnvironment() }
#Preview("Onboarding") { OnboardingFlow().previewEnvironment() }
#Preview("Event picker") { EventPickerScreen { _ in }.previewEnvironment() }
#Preview("Task picker") { TaskPickerScreen(excluded: []) { _ in }.previewEnvironment() }
#Preview("Problems") { ProblemsSheet().previewEnvironment() }
#endif
