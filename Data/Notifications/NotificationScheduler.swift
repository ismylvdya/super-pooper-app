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
    /// Puts a notification the user swiped away or tapped back into Notification Center (silently), under an
    /// identifier of its own: it never takes the place of the pending request of the same slot (tomorrow's).
    func restore(_ request: UNNotificationRequest) async
}

struct UserNotificationScheduler: NotificationScheduling {
    let calendar: CalendarSource
    let rules: RulesConfig.Notifications
    let icons: IconSet
    let bodyText: @Sendable (PlannedNotification.Kind) -> String
    /// The words of an action button, by its title key in `actions.json`.
    let actionTitle: @Sendable (String) -> String
    /// The picture of habit notifications; nil = none.
    var habitIcon: NotificationIcon?
    var center: NotificationCenterClient = SystemNotificationCenter()

    func access() async -> SourceAccess {
        switch await center.authorizationStatus() {
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
                                            title: actionTitle(definition.title),
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
    /// same from day to day, and a moved item must be rescheduled even when its identifier did not change. Notifications
    /// put back after a swipe (pending for a moment, then shown) are kept like shown ones: while their item is still open.
    func sync(planned: [PlannedNotification], stillValid: [PlannedNotification], now immediate: [PlannedNotification]) async {
        let ours = await center.pendingRequests().filter { $0.identifier.hasPrefix(NotificationPayload.prefix) }
        let restoring = ours.filter { NotificationIdentifier.isRestored($0.identifier) }
        let pending = ours.filter { !NotificationIdentifier.isRestored($0.identifier) }
        let wanted = Dictionary(planned.map { (identifier(for: $0), $0.fireDate) }, uniquingKeysWith: { first, _ in first })
        let current = Dictionary(pending.map { ($0.identifier, fireDate(of: $0)) }, uniquingKeysWith: { first, _ in first })
        let outdated = current.filter { id, date in
            guard let want = wanted[id] else { return true }
            return date.map { abs($0.timeIntervalSince(want)) > rules.fireTimeToleranceSeconds } ?? true
        }
        center.removePendingRequests(withIdentifiers: Array(outdated.keys))
        for notification in planned {
            // A newer plan is waiting: it will add what is still missing.
            if Task.isCancelled { return }
            let id = identifier(for: notification)
            guard current[id] == nil || outdated[id] != nil else { continue }
            try? await center.add(request(for: notification))
        }
        for notification in immediate {
            let content = self.content(for: notification)
            try? await center.add(UNNotificationRequest(identifier: NotificationIdentifier.late(identifier(for: notification)),
                                                        content: content, trigger: nil))
        }

        // Shown ones stay only while their item is still open for their day (identifier + day); one put back gives way to
        // a newer notification of its slot, as a shown one is replaced by it.
        let valid = Set(stillValid.flatMap { notification in
            let id = identifier(for: notification)
            return [id, NotificationIdentifier.late(id)].map { $0 + "#" + notification.day.isoString }
        })
        let delivered = await center.deliveredRequests().filter { $0.identifier.hasPrefix(NotificationPayload.prefix) }
        let shownAgain = Set(delivered.map(\.identifier).filter { !NotificationIdentifier.isRestored($0) })
        let isStale = { (request: UNNotificationRequest) -> Bool in
            let day = request.content.userInfo[NotificationPayload.dayKey] as? String ?? ""
            let shown = NotificationIdentifier.shown(request.identifier)
            return !valid.contains(shown + "#" + day) || (shown != request.identifier && shownAgain.contains(shown))
        }
        center.removeDeliveredNotifications(withIdentifiers: delivered.filter(isStale).map(\.identifier))
        center.removePendingRequests(withIdentifiers: restoring.filter(isStale).map(\.identifier))
    }

    /// The moment a pending request was asked for, worked out from its trigger (not from the wall clock).
    private func fireDate(of request: UNNotificationRequest) -> Date? {
        (request.trigger as? UNCalendarNotificationTrigger).flatMap { calendar.current.date(from: $0.dateComponents) }
    }

    func removeAll() async {
        let pending = await center.pendingRequests().map(\.identifier).filter { $0.hasPrefix(NotificationPayload.prefix) }
        center.removePendingRequests(withIdentifiers: pending)
    }

    func restore(_ original: UNNotificationRequest) async {
        guard original.identifier.hasPrefix(NotificationPayload.prefix) else { return }
        let content = (original.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        content.sound = nil
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: rules.restoreDelaySeconds, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: NotificationIdentifier.restored(original.identifier),
                                                    content: content, trigger: trigger))
    }

    /// Habits keep one identifier per time slot (the new day's notification replaces the old one);
    /// everything else carries its fire time, so a moved item gets a fresh notification.
    private func identifier(for notification: PlannedNotification) -> String {
        if notification.kind == .habit, notification.id == notification.key { return NotificationPayload.prefix + notification.id }
        return "\(NotificationPayload.prefix)\(notification.id)@\(Int(notification.fireDate.timeIntervalSince1970))"
    }

    private func request(for notification: PlannedNotification) -> UNNotificationRequest {
        let content = content(for: notification)
        let trigger = UNCalendarNotificationTrigger(dateMatching: NotificationTrigger.components(for: notification, calendar: calendar.current),
                                                    repeats: false)
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
