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
        guard let action = ActionID(rawValue: response.actionIdentifier),
              let taskName = response.notification.request.content.userInfo[NotificationPayload.taskKey] as? String,
              !taskName.isEmpty else { return }
        await MainActor.run { BackgroundRefresh.performAction(action, taskName: taskName) }
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

    static func performAction(_ action: ActionID, taskName: String) {
        guard case .success(let container) = AppContainer.shared else { return }
        pending = Task {
            await container.model.ensureLoaded()
            await container.model.perform(action, on: taskName)
        }
    }

    nonisolated static func waitForPendingWork() async {
        let task = await MainActor.run { pending }
        await task?.value
    }
}
