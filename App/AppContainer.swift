import Foundation
import UserNotifications

/// Composition root: every dependency is created here, once, and handed down.
@MainActor
final class AppContainer {
    let config: AppConfig
    let model: AppModel
    let router: Router
    let banners: BannerCenter
    let launch: LaunchOptions
    let eventKit: EventKitAccess

    /// The single instance shared by the SwiftUI app and the UIKit delegate.
    static let shared: Result<AppContainer, ConfigError> = {
        do {
            return .success(try AppContainer(config: AppConfig.load(), launch: .current()))
        } catch let error as ConfigError {
            return .failure(error)
        } catch {
            return .failure(ConfigError(file: "?", path: "", message: error.localizedDescription))
        }
    }()

    #if DEBUG
    /// The app clock (honours `-SPNow`) for DEBUG screens.
    static var sharedClockNow: Date {
        guard case .success(let container) = shared else { return Date() }
        return container.model.clock.now
    }
    #endif

    init(config: AppConfig, launch: LaunchOptions) {
        self.config = config
        self.launch = launch
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = Weekday.monday.rawValue + 1
        calendar.locale = Locale.current

        let shared = JSONFileStore(directory: AppGroupContainer.directory())
        if launch.resetState {
            shared.remove(SettingsStore.fileName)
            shared.remove(DayStateStore.fileName)
        }
        let clock: Clock = launch.now.map { time in
            ShiftedClock(startingAt: LocalDate(Date(), in: calendar).startDate(in: calendar, offset: time))
        } ?? SystemClock()

        let vaultLocation: VaultLocating = launch.vaultURL().map(FixedVaultLocation.init(url:))
            ?? BookmarkVaultLocation(store: shared)
        let settingsStore = SettingsStore(store: shared, defaults: config.defaultSettings)
        let fileSystem = CoordinatedFileSystem()
        let backups = BackupService(directory: shared.url("Backups"), keepCount: config.rules.backups.keepCount,
                                    fileSystem: fileSystem, clock: { clock.now })
        let tasks = VaultTaskRepository(location: vaultLocation, fileSystem: fileSystem, ubiquity: ICloudUbiquityService(),
                                        mapping: config.fieldMapping, calendar: calendar, rules: config.rules.vault,
                                        backups: backups, clock: clock,
                                        vaultSettings: { settingsStore.load().vault })
        let eventKit = EventKitAccess()
        self.eventKit = eventKit
        let notifications = UserNotificationScheduler(calendar: calendar, icons: config.icons) { kind in
            switch kind {
            case .habit: L10n.string("notification.habit.body")
            case .task: L10n.string("notification.task.body")
            case .reminder: L10n.string("notification.reminder.body")
            }
        }
        let services = AppServices(
            vault: vaultLocation, tasks: tasks,
            trash: VaultTrashRepository(location: vaultLocation, fileSystem: fileSystem, noteExtension: config.rules.vault.noteExtension,
                                        vaultSettings: { settingsStore.load().vault }),
            calendars: EventKitCalendarRepository(eventKit: eventKit),
            reminders: EventKitRemindersRepository(eventKit: eventKit, calendar: calendar),
            notifications: notifications, settingsStore: settingsStore,
            dayStateStore: DayStateStore(store: shared), snapshotStore: SnapshotStore(store: shared),
            widgets: WidgetKitReloader())

        let banners = BannerCenter()
        self.banners = banners
        self.router = Router()
        self.model = AppModel(config: config, services: services, banners: banners, clock: clock, calendar: calendar)
        Haptics.isEnabled = config.flags.haptics
        notifications.registerCategories(config.actions, habitActionsEnabled: config.flags.habitNotificationActions)

        if launch.skipOnboarding { model.updateSettings { $0.onboarding.completed = true } }
        if let layout = launch.timelineLayout { model.updateSettings { $0.timeline.layout = layout } }
        if let arrangement = launch.arrangement { model.updateSettings { $0.today.arrangement = arrangement } }
    }

    /// First sync after launch (DEBUG: optionally seeds demo calendar data first).
    func start() async {
        #if DEBUG
        if launch.seedDemo {
            if let sources = await DemoDataSeeder(eventKit: eventKit, calendar: model.calendar, clock: model.clock).seed() {
                model.updateSettings {
                    $0.sources.anchorCalendarIDs = [sources.calendarID]
                    $0.sources.reminderListIDs = [sources.reminderListID]
                }
            }
        }
        if launch.provisionalNotifications {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .provisional])
        }
        #endif
        await model.sync(announce: false)
        if let url = launch.openURL { router.handle(url) }
    }
}
