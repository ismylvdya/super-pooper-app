import Foundation
@preconcurrency import UserNotifications

/// Runs what a notification response asks for (`NotificationResponseRouter`), without opening the app when iOS allows.
/// Task and habit actions run one after another, each after the first load of the tasks; an edit of Calendar or
/// Reminders waits for the read it causes, so the app is not suspended before the widgets and notifications follow.
@MainActor
final class NotificationResponseHandler {
    private let model: AppModel
    private let router: NotificationResponseRouter
    private let open: @MainActor (URL) async -> Void
    private var pending: Task<Void, Never>?

    init(model: AppModel, router: NotificationResponseRouter, open: @escaping @MainActor (URL) async -> Void) {
        self.model = model
        self.router = router
        self.open = open
    }

    func handle(action: String, request: UNNotificationRequest) async {
        switch router.route(action: action, info: request.content.userInfo) {
        case .putBack(let url):
            await model.restoreNotification(request)
            if let url { await open(url) }
        case .completeReminder(let id):
            await model.ensureLoaded()
            await model.completeReminder(id: id)
            await model.waitForSourceRefresh()
        case .deleteEvent(let identifier, let start):
            await model.ensureLoaded()
            await model.deleteEvent(identifier: identifier, start: start)
            await model.waitForSourceRefresh()
        case .snooze(let key, let day):
            // The snoozed notification is planned from today's notifications: the tasks and sources are read first.
            await model.ensureLoaded()
            await model.snoozeNotification(key: key, day: day, shown: request.identifier)
        case .dismiss:
            await model.dismissNotification(shown: request.identifier)
        case .perform(let chosen, let taskName, let day):
            let previous = pending
            let job = Task {
                await previous?.value
                await model.ensureLoaded()
                await model.performNotificationAction(chosen, on: taskName, day: day)
            }
            pending = job
            await job.value
        case .ignore:
            break
        }
    }
}
