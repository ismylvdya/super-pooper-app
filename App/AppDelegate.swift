import BackgroundTasks
import UIKit
@preconcurrency import UserNotifications

/// UIKit hooks: notification actions (run without opening the app when iOS allows) and
/// background refresh scheduling.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UINavigationBar.appearance().tintColor = .label
        MainActor.assumeIsolated {
            AppActionBridge.syncHandler = {
                guard case .success(let container) = AppContainer.shared else { return }
                await container.model.sync(announce: false)
            }
            AppActionBridge.habitTapHandler = { name in
                guard case .success(let container) = AppContainer.shared else { return }
                await container.model.ensureLoaded()
                await container.model.cycleHabit(name, on: container.model.context().today)
            }
        }
        return true
    }

    /// A scene delegate of our own only to receive Home Screen quick actions.
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// Swiping or tapping a notification does nothing to the data: the item stays in the day, and the
    /// notification comes back silently until it is marked. Buttons on it run their action.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        if response.actionIdentifier == UNNotificationDismissActionIdentifier || response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            await BackgroundRefresh.restore(response.notification)
            return
        }
        if (info[NotificationPayload.kindKey] as? String) == PlannedNotification.Kind.reminder.rawValue,
           let reminderID = info[NotificationPayload.reminderKey] as? String, !reminderID.isEmpty,
           response.actionIdentifier == ActionID.done.rawValue {
            await BackgroundRefresh.completeReminder(reminderID)
            return
        }
        guard let action = ActionID(rawValue: response.actionIdentifier),
              let taskName = info[NotificationPayload.taskKey] as? String, !taskName.isEmpty else { return }
        let day = (info[NotificationPayload.dayKey] as? String).flatMap(LocalDate.init(isoString:))
        await MainActor.run { BackgroundRefresh.performAction(action, taskName: taskName, day: day) }
        await BackgroundRefresh.waitForPendingWork()
    }
}
