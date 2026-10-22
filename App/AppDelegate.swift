import BackgroundTasks
import UIKit
@preconcurrency import UserNotifications

/// UIKit hooks: notification actions (run without opening the app when iOS allows) and
/// background refresh scheduling.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// Tapping or dismissing does nothing to the data: the item simply stays in the day.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let action = ActionID(rawValue: response.actionIdentifier),
              let taskName = info[NotificationPayload.taskKey] as? String, !taskName.isEmpty else { return }
        let day = (info[NotificationPayload.dayKey] as? String).flatMap(LocalDate.init(isoString:))
        await MainActor.run { BackgroundRefresh.performAction(action, taskName: taskName, day: day) }
        await BackgroundRefresh.waitForPendingWork()
    }
}

/// Background app refresh: re-read the vault, update widgets and the notification schedule.
@MainActor
enum BackgroundRefresh {
    static var identifier: String { (Bundle.main.bundleIdentifier ?? "SuperPooperApp") + ".refresh" }
    private static var pending: Task<Void, Never>?

    static func schedule() {
        guard case .success(let container) = AppContainer.shared, container.config.flags.backgroundRefresh else { return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date().addingTimeInterval(30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func run() async {
        guard case .success(let container) = AppContainer.shared else { return }
        await container.model.sync(announce: false)
        schedule()
    }

    /// Actions run one after another; each waits for the first load of the vault.
    static func performAction(_ action: ActionID, taskName: String, day: LocalDate?) {
        guard case .success(let container) = AppContainer.shared else { return }
        let previous = pending
        pending = Task {
            await previous?.value
            await container.model.ensureLoaded()
            await container.model.perform(action, on: taskName, day: day)
        }
    }

    nonisolated static func waitForPendingWork() async {
        let task = await MainActor.run { pending }
        await task?.value
    }
}
