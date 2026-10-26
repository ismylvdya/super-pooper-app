import BackgroundTasks
import UIKit

/// Background app refresh: re-read the vault, update widgets and the notification schedule.
@MainActor
enum BackgroundRefresh {
    static var identifier: String { (Bundle.main.bundleIdentifier ?? "SuperPooperApp") + ".refresh" }
    private static var pending: Task<Void, Never>?

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

    /// Actions run one after another; each waits for the first load of the vault.
    static func performAction(_ action: ActionID, taskName: String, day: LocalDate?) {
        guard case .success(let container) = AppContainer.shared else { return }
        let previous = pending
        pending = Task {
            await previous?.value
            await container.model.ensureLoaded()
            await container.model.performNotificationAction(action, on: taskName, day: day)
        }
    }

    static func completeReminder(_ id: String) async {
        guard case .success(let container) = AppContainer.shared else { return }
        await container.model.ensureLoaded()
        await container.model.completeReminder(id: id)
    }

    /// Delete event on an event alert: the occurrence that alert belongs to.
    static func deleteEvent(_ identifier: String, start: Date) async {
        guard case .success(let container) = AppContainer.shared else { return }
        await container.model.ensureLoaded()
        await container.model.deleteEvent(identifier: identifier, start: start)
    }

    /// A notification of a day that is over is not put back: it goes with its day.
    static func restore(_ notification: UNNotification) async {
        guard case .success(let container) = AppContainer.shared else { return }
        let day = (notification.request.content.userInfo[NotificationPayload.dayKey] as? String).flatMap(LocalDate.init(isoString:))
        guard !StaleNotifications.isOver(day, today: container.model.context().today) else { return }
        await container.model.services.notifications.restore(notification)
    }

    nonisolated static func waitForPendingWork() async {
        let task = await MainActor.run { pending }
        await task?.value
    }
}
