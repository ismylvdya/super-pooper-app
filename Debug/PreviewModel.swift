#if DEBUG
import SwiftUI
@preconcurrency import UserNotifications

/// An app model on in-memory sample data for SwiftUI previews of whole screens.
@MainActor
enum PreviewModel {
    static func make(notifications: NotificationScheduling = SilentNotifications(),
                     reminders: RemindersRepository = StaticRemindersRepository(),
                     calendars: CalendarRepository = StaticCalendarRepository(),
                     calendar: CalendarSource = FixedCalendar(current: PreviewSamples.calendar),
                     clock: Clock = FixedClock(now: PreviewSamples.context.now),
                     tasks: [TaskItem] = PreviewSamples.tasks,
                     delay: Delay = SleepDelay(),
                     signature: AppSignatureReading = FixedSignature(date: nil),
                     appEvents: AppEventSink? = nil) -> (model: AppModel, router: Router, config: AppConfig, banners: BannerCenter)? {
        guard let config = try? AppConfig.load(), let mapping = try? FieldMapping.load() else { return nil }
        let store = JSONFileStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperPooperPreview-\(UUID().uuidString)"))
        let settingsStore = SettingsStore(store: store, defaults: config.defaultSettings)
        let memory = InMemoryTaskStore(tasks: tasks, names: ObsidianNoteNames(rules: mapping.obsidian.noteNames))
        let services = AppServices(
            vault: FixedVaultLocation(url: store.directory), tasks: memory,
            trash: TaskNotesTrash(location: FixedVaultLocation(url: store.directory), fileSystem: CoordinatedFileSystem(),
                                        noteExtension: mapping.obsidian.noteExtension, vaultSettings: { settingsStore.load().vault }),
            versions: memory, links: memory, backups: memory, folder: memory,
            settingsNote: VaultSettingsFile(location: FixedVaultLocation(url: store.directory), fileSystem: CoordinatedFileSystem(),
                                            rules: config.rules.vault, vaultSettings: { settingsStore.load().vault }),
            calendars: calendars, reminders: reminders, notifications: notifications,
            settingsStore: settingsStore, dayStateStore: DayStateStore(store: store),
            snapshotStore: SnapshotStore(store: store), alertStateStore: AlertStateStore(store: store),
            snoozeStore: SnoozeStore(store: store), widgets: NoWidgets(),
            notificationImage: NotificationImageStore(url: store.url(config.rules.notifications.imageFile), maxPixels: 1),
            signature: signature)
        let banners = BannerCenter()
        let model = AppModel(config: config, services: services, appEvents: appEvents ?? BannerPresenter(banners: banners), clock: clock,
                             calendar: calendar, delay: delay)
        model.parts.tasks.setScanResult(VaultScanResult(tasks: tasks, fileProblems: [], conflicted: []))
        model.parts.sources.replaceItems(events: PreviewSamples.events, reminders: PreviewSamples.reminders)
        return (model, Router(), config, banners)
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
                    .environment(preview.banners)
                    .appConfig(preview.config)
            } else {
                Text(verbatim: "Config error")
            }
        }
    }
}

struct StaticCalendarRepository: CalendarRepository {
    var access: SourceAccess { .granted }
    func requestAccess() async -> Bool { true }
    func calendars() -> [SourceCollection] { [SourceCollection(id: "demo", title: "Demo", colorHex: "#30B0C7", sourceTitle: "iCloud")] }
    func events(from start: Date, to end: Date, calendarIDs: [String]) -> [CalendarEvent] { PreviewSamples.events }
    func delete(_ event: CalendarEvent) throws {}
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}

struct StaticRemindersRepository: RemindersRepository {
    var access: SourceAccess { .granted }
    func requestAccess() async -> Bool { true }
    func lists() -> [SourceCollection] { [SourceCollection(id: "list", title: "Remember", colorHex: "#FF9500", sourceTitle: "iCloud")] }
    func reminders(from start: Date, to end: Date, listIDs: [String]) async -> [ReminderItem] { PreviewSamples.reminders }
    func setCompleted(_ completed: Bool, reminderID: String) throws {}
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}

struct SilentNotifications: NotificationScheduling {
    func access() async -> SourceAccess { .granted }
    func requestAccess() async -> Bool { true }
    func registerCategories(_ registry: ActionRegistry, habitActionsEnabled: Bool) {}
    func sync(planned: [PlannedNotification], stillValid: [PlannedNotification], now immediate: [PlannedNotification]) async {}
    func removeAll() async {}
    func restore(_ request: UNNotificationRequest) async {}
    func remove(shown identifier: String) async {}
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
