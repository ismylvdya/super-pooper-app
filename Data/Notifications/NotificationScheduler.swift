@preconcurrency import UserNotifications

/// Local notifications behind a protocol (the planner decides what, this only talks to iOS).
protocol NotificationScheduling: Sendable {
    func access() async -> SourceAccess
    func requestAccess() async -> Bool
    func registerCategories(_ registry: ActionRegistry, habitActionsEnabled: Bool)
    /// Makes the pending set equal to `planned`; delivered notifications whose source is gone,
    /// done or moved (not in `stillValid`, i.e. today's plan including past times) are removed.
    func sync(planned: [PlannedNotification], stillValid: [PlannedNotification]) async
    func removeAll() async
    /// Puts a notification the user swiped away or tapped back into Notification Center (silently).
    func restore(_ notification: UNNotification) async
}

/// `userInfo` keys and category ids shared with the notification delegate.
enum NotificationPayload {
    static let prefix = "sp|"
    static let kindKey = "kind"
    static let taskKey = "task"
    static let dayKey = "day"
    static let reminderKey = "reminder"
    static let habitCategory = "habit"
    static let taskCategory = "task"
    static let reminderCategory = "reminder"
}

struct UserNotificationScheduler: NotificationScheduling {
    let calendar: Calendar
    let icons: IconSet
    let bodyText: @Sendable (PlannedNotification.Kind) -> String

    private var center: UNUserNotificationCenter { .current() }

    func access() async -> SourceAccess {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    func requestAccess() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func registerCategories(_ registry: ActionRegistry, habitActionsEnabled: Bool) {
        func category(_ id: String, _ menu: ActionMenu) -> UNNotificationCategory {
            let actions = registry.actions(in: menu).map { definition in
                // Habit buttons get the same mark images as the app's habit menus.
                let icon = menu.isHabitMenu
                    ? HabitMarkIcon.icon(for: definition.id).map { UNNotificationActionIcon(templateImageName: icons[$0]) }
                    : nil
                return UNNotificationAction(identifier: definition.id.rawValue,
                                            title: String(localized: String.LocalizationValue(definition.title)),
                                            options: definition.destructive ? [.destructive] : [],
                                            icon: icon ?? UNNotificationActionIcon(systemImageName: definition.icon))
            }
            return UNNotificationCategory(identifier: id, actions: actions, intentIdentifiers: [], options: [.customDismissAction])
        }
        let habit = habitActionsEnabled
            ? category(NotificationPayload.habitCategory, .habitNotification)
            : UNNotificationCategory(identifier: NotificationPayload.habitCategory, actions: [], intentIdentifiers: [],
                                     options: [.customDismissAction])
        center.setNotificationCategories([
            habit,
            category(NotificationPayload.taskCategory, .taskNotification),
            category(NotificationPayload.reminderCategory, .reminderNotification),
        ])
    }

    func sync(planned: [PlannedNotification], stillValid: [PlannedNotification]) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(NotificationPayload.prefix) }
        let wanted = Set(planned.map { identifier(for: $0) })
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { !wanted.contains($0) })

        let pendingSet = Set(pending)
        for notification in planned where !pendingSet.contains(identifier(for: notification)) {
            try? await center.add(request(for: notification))
        }

        let validIdentifiers = Set(stillValid.map { identifier(for: $0) })
        let delivered = await center.deliveredNotifications().map(\.request.identifier)
        center.removeDeliveredNotifications(withIdentifiers: delivered.filter {
            $0.hasPrefix(NotificationPayload.prefix) && !validIdentifiers.contains($0)
        })
    }

    func removeAll() async {
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(NotificationPayload.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
    }

    func restore(_ notification: UNNotification) async {
        let original = notification.request
        guard original.identifier.hasPrefix(NotificationPayload.prefix) else { return }
        let content = (original.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        content.sound = nil
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: original.identifier, content: content, trigger: trigger))
    }

    /// The fire time is part of the identifier, so a moved task gets a fresh notification.
    private func identifier(for notification: PlannedNotification) -> String {
        "\(NotificationPayload.prefix)\(notification.id)@\(Int(notification.fireDate.timeIntervalSince1970))"
    }

    private func request(for notification: PlannedNotification) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = bodyText(notification.kind)
        content.sound = .default
        content.categoryIdentifier = switch notification.kind {
        case .habit: NotificationPayload.habitCategory
        case .task: NotificationPayload.taskCategory
        case .reminder: NotificationPayload.reminderCategory
        }
        content.userInfo = [
            NotificationPayload.kindKey: notification.kind.rawValue,
            NotificationPayload.taskKey: notification.taskName ?? "",
            NotificationPayload.dayKey: notification.day.isoString,
            NotificationPayload.reminderKey: notification.reminderID ?? "",
        ]
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notification.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: identifier(for: notification), content: content, trigger: trigger)
    }
}
