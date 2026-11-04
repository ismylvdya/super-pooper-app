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
            AppActionBridge.alarmDoneHandler = { name, day in
                guard case .success(let container) = AppContainer.shared, !name.isEmpty else { return }
                await container.model.ensureLoaded()
                await container.model.performNotificationAction(.done, on: name, day: day)
            }
            AppActionBridge.alarmSnoozeHandler = { key, day in
                guard case .success(let container) = AppContainer.shared else { return }
                await container.model.ensureLoaded()
                await container.model.snoozeNotification(key: key, day: day, shown: "")
            }
            AppActionBridge.signingCheckHandler = {
                guard case .success(let container) = AppContainer.shared else { return nil }
                return await container.checkSigning()
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

    /// A swipe, a tap or a button on one of the app's notifications (`NotificationResponseRouter`), on the main actor
    /// where the app's state lives.
    @MainActor func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let responses = notificationResponses() else { return }
        await responses.handle(action: response.actionIdentifier, request: response.notification.request)
    }

    @MainActor private func notificationResponses() -> NotificationResponseHandler? {
        guard case .success(let container) = AppContainer.shared else { return nil }
        return container.notificationResponses
    }
}
