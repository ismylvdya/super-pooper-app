@preconcurrency import UserNotifications

/// Local notifications behind a protocol (the planner decides what, this only talks to iOS).
protocol NotificationScheduling: Sendable {
    func access() async -> SourceAccess
    func requestAccess() async -> Bool
    func registerCategories(_ registry: ActionRegistry, habitActionsEnabled: Bool)
    /// Makes the pending set equal to `planned`; delivered notifications whose source is gone,
    /// done or moved (not in `stillValid`, i.e. today's plan including past times) are removed.
    /// `immediate`: alerts whose time already passed without a notification (moved into the past), sent now.
    func sync(planned: [PlannedNotification], stillValid: [PlannedNotification], now immediate: [PlannedNotification]) async
    func removeAll() async
    /// Puts a notification the user swiped away or tapped back into Notification Center (silently).
    func restore(_ notification: UNNotification) async
}

struct UserNotificationScheduler: NotificationScheduling {
    let calendar: Calendar
    let icons: IconSet
    let bodyText: @Sendable (PlannedNotification.Kind) -> String
    /// The picture of habit notifications; nil = none.
    var habitIcon: NotificationIcon?

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
            category(NotificationPayload.eventCategory, .eventNotification),
        ])
    }

    /// Pending requests are compared by identifier and fire time: a habit's slot identifier stays the
    /// same from day to day, and a moved item must be rescheduled even when its identifier did not change.
    func sync(planned: [PlannedNotification], stillValid: [PlannedNotification], now immediate: [PlannedNotification]) async {
        let pending = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix(NotificationPayload.prefix) }
        let wanted = Dictionary(planned.map { (identifier(for: $0), $0.fireDate) }, uniquingKeysWith: { first, _ in first })
        let current = Dictionary(pending.map { ($0.identifier, fireDate(of: $0)) }, uniquingKeysWith: { first, _ in first })
        let outdated = current.filter { id, date in
            guard let want = wanted[id] else { return true }
            return date.map { abs($0.timeIntervalSince(want)) > 30 } ?? true
        }
        center.removePendingNotificationRequests(withIdentifiers: Array(outdated.keys))
        for notification in planned {
            // A newer plan is waiting: it will add what is still missing.
            if Task.isCancelled { return }
            let id = identifier(for: notification)
            guard current[id] == nil || outdated[id] != nil else { continue }
            try? await center.add(request(for: notification))
        }
        for notification in immediate {
            let content = self.content(for: notification)
            try? await center.add(UNNotificationRequest(identifier: identifier(for: notification) + "|late", content: content, trigger: nil))
        }

        // Delivered ones stay only while their item is still open for their day (identifier + day).
        let valid = Set(stillValid.flatMap { [identifier(for: $0) + "#" + $0.day.isoString, identifier(for: $0) + "|late#" + $0.day.isoString] })
        let delivered = await center.deliveredNotifications().map(\.request)
        center.removeDeliveredNotifications(withIdentifiers: delivered.filter { request in
            let day = request.content.userInfo[NotificationPayload.dayKey] as? String ?? ""
            return request.identifier.hasPrefix(NotificationPayload.prefix) && !valid.contains(request.identifier + "#" + day)
        }.map(\.identifier))
    }

    private func fireDate(of request: UNNotificationRequest) -> Date? {
        (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
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

    /// Habits keep one identifier per time slot (the new day's notification replaces the old one);
    /// everything else carries its fire time, so a moved item gets a fresh notification.
    private func identifier(for notification: PlannedNotification) -> String {
        if notification.kind == .habit, notification.id == notification.key { return NotificationPayload.prefix + notification.id }
        return "\(NotificationPayload.prefix)\(notification.id)@\(Int(notification.fireDate.timeIntervalSince1970))"
    }

    private func request(for notification: PlannedNotification) -> UNNotificationRequest {
        let content = content(for: notification)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notification.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: identifier(for: notification), content: content, trigger: trigger)
    }

    /// A phone plays the default sound; the simulator, where the app is tested all day, stays quiet.
    private static var alertSound: UNNotificationSound? {
        #if targetEnvironment(simulator)
        nil
        #else
        .default
        #endif
    }

    private func content(for notification: PlannedNotification) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.start.map { start in
            "\(bodyText(notification.kind)) \(start.formatted(date: .omitted, time: .shortened))"
        } ?? bodyText(notification.kind)
        content.sound = Self.alertSound
        content.threadIdentifier = notification.key
        if notification.kind == .habit, let icon = habitIcon?.attachment(habitColor: notification.colorHex) {
            content.attachments = [icon]
        }
        content.categoryIdentifier = switch notification.kind {
        case .habit: NotificationPayload.habitCategory
        case .task: NotificationPayload.taskCategory
        case .reminder: NotificationPayload.reminderCategory
        case .event: NotificationPayload.eventCategory
        }
        content.userInfo = [
            NotificationPayload.kindKey: notification.kind.rawValue,
            NotificationPayload.taskKey: notification.taskName ?? "",
            NotificationPayload.dayKey: notification.day.isoString,
            NotificationPayload.reminderKey: notification.reminderID ?? "",
            NotificationPayload.eventKey: notification.eventID ?? "",
            NotificationPayload.eventStartKey: notification.start?.timeIntervalSince1970 ?? 0,
        ]
        return content
    }
}
