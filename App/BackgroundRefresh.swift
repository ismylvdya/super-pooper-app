import BackgroundTasks
import UIKit

/// Background app refresh: re-read the vault, update widgets and the notification schedule.
@MainActor
enum BackgroundRefresh {
    static var identifier: String { (Bundle.main.bundleIdentifier ?? "SuperPooperApp") + ".refresh" }

    static func schedule() {
        guard case .success(let container) = AppContainer.shared, container.config.flags.backgroundRefresh else { return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        // Asked for no later than the end of the logical day: the refresh then clears that day's notifications.
        let interval = Double(container.config.rules.widgets.backgroundRefreshMinutes) * 60
        request.earliestBeginDate = min(container.model.clock.now.addingTimeInterval(interval), container.model.context().dayEnd)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func run() async {
        guard case .success(let container) = AppContainer.shared else { return }
        await container.model.sync(announce: false)
        await container.model.waitForNotifications()
        schedule()
    }
}
