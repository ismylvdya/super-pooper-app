import Foundation

/// What follows every change of the data: the widget snapshot and reload, and the notification schedule.
extension AppModel {
    /// Widgets snapshot, widget reload and notification schedule follow every change.
    func publishDerivedState() async {
        let context = context()
        if config.flags.widgetSnapshot {
            // The widget shows the next hours from this one snapshot, past the day boundary too.
            let widgets = config.rules.widgets
            let reach = context.dayEnd.addingTimeInterval(Double(widgets.entryCount * widgets.refreshMinutes) * 60)
            let snapshot = WidgetSnapshot(generatedAt: context.now, tasks: tasks, events: events,
                                          reminders: reminders.filter { $0.due >= context.dayStart && $0.due < reach }, dayState: dayState)
            try? services.snapshotStore.save(snapshot)
        }
        services.widgets.reloadAll()
        // The notification center can be slow to answer (or not answer at all in a broken simulator);
        // a sync never waits for it. Plans go one after another, so an older one still being scheduled cannot
        // finish after the newest; a plan already replaced by a newer one is skipped.
        let previous = notificationTask
        previous?.cancel()
        notificationTask = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await rescheduleNotifications(context: context)
        }
    }

    /// Background refresh waits for the notification schedule before the app is suspended.
    func waitForNotifications() async {
        await notificationTask?.value
    }

    func rescheduleNotifications(context: DayContext) async {
        guard config.flags.notifications, settings.notifications.enabled else {
            await services.notifications.removeAll()
            return
        }
        let rules = config.rules.notifications
        let planner = NotificationPlanner(horizonDays: rules.horizonDays, limit: rules.limit)
        // Skip today (habits) and Not today (tasks) both take an item out of today's notifications.
        let skipped = Set(dayState.day == context.today ? dayState.skipped + dayState.postponed : [])
        let planned = planner.plan(tasks: tasks, reminders: reminders, events: events, skipped: skipped, context: context)
        let valid = planner.stillValidToday(tasks: tasks, reminders: reminders, events: events, skipped: skipped, context: context)
        // Alerts moved into the past or added too late come right away, once.
        let all = planner.all(tasks: tasks, reminders: reminders, events: events, skipped: skipped, context: context)
        let previous = services.alertStateStore.load()
        let late = LateAlerts.due(all, pending: previous?.pending ?? [:], known: previous.map { Set($0.known) },
                                  now: context.now, calendar: calendar)
        try? services.alertStateStore.save(AlertState(
            pending: Dictionary(planned.map { ($0.key, $0.fireDate) }, uniquingKeysWith: min),
            known: Array(Set(all.map(\.key)))))
        await services.notifications.sync(planned: planned, stillValid: valid + late, now: late)
    }
}
