import Foundation
import SwiftUI
import UserNotifications

/// Composition root: every dependency is created here, once, and handed down.
@MainActor
final class AppContainer {
    let config: AppConfig
    let model: AppModel
    let router: Router
    let banners: BannerCenter
    let notificationResponses: NotificationResponseHandler
    let launch: LaunchOptions
    let eventKit: EventKitAccess
    let calendar: LiveCalendar

    /// The single instance shared by the SwiftUI app and the UIKit delegate.
    static let shared: Result<AppContainer, ConfigError> = {
        do {
            return .success(try AppContainer(config: AppConfig.load(), mapping: FieldMapping.load(), launch: .current()))
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

    init(config: AppConfig, mapping: FieldMapping, launch: LaunchOptions) {
        self.config = config
        self.launch = launch
        let calendar = LiveCalendar()
        self.calendar = calendar

        let shared = JSONFileStore(directory: AppGroupContainer.directory())
        if launch.resetState {
            shared.remove(SettingsStore.fileName)
            shared.remove(DayStateStore.fileName)
        }
        let clock = launch.clock(calendar: calendar.current)

        let vaultLocation: VaultLocating = launch.vaultURL().map(FixedVaultLocation.init(url:))
            ?? BookmarkVaultLocation(store: shared)
        let settingsStore = SettingsStore(store: shared, defaults: config.defaultSettings)
        let fileSystem = CoordinatedFileSystem()
        let backups = BackupService(directory: shared.url("Backups"), keepCount: config.rules.backups.keepCount,
                                    fileSystem: fileSystem, clock: { clock.now }, calendar: calendar)
        let tasks = TaskNotesStore(location: vaultLocation, fileSystem: fileSystem, ubiquity: ICloudUbiquityService(),
                                        mapping: mapping, calendar: calendar, rules: config.rules.vault,
                                        backups: backups, clock: clock,
                                        vaultSettings: { settingsStore.load().vault })
        let eventKit = EventKitAccess()
        self.eventKit = eventKit
        let notificationImage = NotificationImageStore(url: shared.url(config.rules.notifications.imageFile),
                                                       maxPixels: config.rules.notifications.imageMaxPixels)
        let notifications = UserNotificationScheduler(calendar: calendar, rules: config.rules.notifications, icons: config.icons, bodyText: NotificationBodyText.text(for:), actionTitle: { L10n.string($0) }, habitIcon: NotificationIcon(symbolName: config.icons[.habit], color: {
            config.tokens.applying(settingsStore.load(), limits: config.rules.limits).uiColor(.habit)
        }, isShown: { settingsStore.load().habits.showsNotificationPicture },
           usesHabitColor: { settingsStore.load().habits.notificationUsesHabitColor },
           pointSize: config.tokens.size(.notificationIcon), image: notificationImage))
        let services = AppServices(
            vault: vaultLocation, tasks: tasks,
            trash: TaskNotesTrash(location: vaultLocation, fileSystem: fileSystem, noteExtension: mapping.obsidian.noteExtension,
                                        vaultSettings: { settingsStore.load().vault }),
            versions: tasks, links: tasks, backups: tasks, folder: tasks,
            settingsNote: VaultSettingsFile(location: vaultLocation, fileSystem: fileSystem, rules: config.rules.vault,
                                            vaultSettings: { settingsStore.load().vault }),
            calendars: EventKitCalendarRepository(eventKit: eventKit),
            reminders: EventKitRemindersRepository(eventKit: eventKit, calendar: calendar),
            notifications: notifications, settingsStore: settingsStore,
            dayStateStore: DayStateStore(store: shared), snapshotStore: SnapshotStore(store: shared),
            alertStateStore: AlertStateStore(store: shared), snoozeStore: SnoozeStore(store: shared),
            widgets: WidgetKitReloader(), notificationImage: notificationImage, signature: launch.signature(now: clock.now))

        let banners = BannerCenter()
        self.banners = banners
        self.router = Router()
        self.model = AppModel(config: config, services: services, appEvents: BannerPresenter(banners: banners), clock: clock,
                              calendar: calendar)
        notificationResponses = NotificationResponseHandler(model: model, router: NotificationResponseRouter(links: config.rules.eventLinks),
                                                            open: { await UIApplication.shared.open($0) })
        Haptics.isEnabled = config.flags.haptics
        Haptics.styles = config.actions.haptics
        notifications.registerCategories(config.actions, habitActionsEnabled: config.flags.habitNotificationActions)

        applyLaunchOverrides()
    }

    /// DEBUG launch arguments that set settings (empty in Release).
    private func applyLaunchOverrides() {
        if launch.skipOnboarding { model.updateSettings { $0.onboarding.completed = true } }
        if let layout = launch.timelineLayout { model.updateSettings { $0.timeline.layout = layout } }
        if let arrangement = launch.arrangement { model.updateSettings { $0.today.arrangement = arrangement } }
    }

    /// The Shortcuts check: warns now if the signature runs out soon; returns when it runs out.
    func checkSigning() async -> Date? {
        await signingReminder.notifyIfSoon(now: model.clock.now)
        return signingReminder.signature.expiration()
    }

    private var signingReminder: SigningExpiryReminder {
        let rules = config.rules.notifications
        return SigningExpiryReminder(identifier: rules.signingWarningID, leadHours: rules.signingWarningHours,
                                     signature: ProvisioningProfileSignature()) { expiration in
            (L10n.string("notification.signing.title"),
             L10n.format("notification.signing.body", expiration.formatted(date: .abbreviated, time: .shortened)))
        }
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
        await signingReminder.schedule(now: model.clock.now)
        // The settings note read by the sync must not undo what the launch asked for.
        applyLaunchOverrides()
        if let url = launch.openURL { router.handle(url) }
        model.observeSourceChanges()
        observeTimeChanges()
    }

    /// A new time zone (a flight, a manual change) or a clock that jumped: the app calendar is built again and the day,
    /// the widgets and the notifications are worked out in it, without a relaunch.
    private func observeTimeChanges() {
        let model = self.model
        let calendar = self.calendar
        for name in [Notification.Name.NSSystemTimeZoneDidChange, UIApplication.significantTimeChangeNotification] {
            Task { @MainActor in
                for await _ in NotificationCenter.default.notifications(named: name) {
                    calendar.refresh()
                    await model.timeDidChange()
                }
            }
        }
    }
}
