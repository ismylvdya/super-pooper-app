import Foundation
@preconcurrency import UserNotifications

/// What follows every change of the data: the day plan, worked out once per change of its data and per minute (a screen
/// asks for it several times per drawing), the widget snapshot and reload, and the notification schedule, planned in
/// its own line (`NotificationQueue`).
@MainActor
final class DerivedStatePublisher {
    private let config: AppConfig
    private let tasks: TaskState
    private let day: DayStateController
    private let sections: DaySectionsController
    private let sources: SourcesController
    private let settings: SettingsController
    private let snapshotStore: SnapshotStore
    private let alertStateStore: AlertStateStore
    private let snoozeStore: SnoozeStore
    private let widgets: WidgetReloading
    private let notifications: NotificationScheduling
    private let mirroring: DayMirroring?
    private let queue = NotificationQueue()
    /// The last plan of each day asked for (0 = today), with what it was worked out from.
    private var plans: [Int: CachedPlan] = [:]

    init(config: AppConfig, tasks: TaskState, day: DayStateController, sections: DaySectionsController, sources: SourcesController,
         settings: SettingsController, services: AppServices) {
        self.config = config
        self.tasks = tasks
        self.day = day
        self.sections = sections
        self.sources = sources
        self.settings = settings
        snapshotStore = services.snapshotStore
        alertStateStore = services.alertStateStore
        snoozeStore = services.snoozeStore
        widgets = services.widgets
        notifications = services.notifications
        mirroring = services.mirroring
    }

    /// Today (`dayOffset` 0) or another day browsed on Today.
    func plan(at date: Date, dayOffset: Int = 0) -> DayPlan {
        let settings = settings.settings
        let context = day.context(at: date)
        let key = PlanKey(tasks: tasks.tasks, events: sources.events, reminders: sources.reminders, dayState: day.dayState,
                          sections: sections.snapshot(on: context.today.adding(days: dayOffset)), settings: settings,
                          calendar: day.calendar, eventsKnown: sources.eventsKnown, minute: PlanKey.minute(of: date))
        if let cached = plans[dayOffset], cached.key == key { return cached.plan }
        let plan = DayPlanning.plan(config: config, settings: settings, tasks: key.tasks, events: key.events, reminders: key.reminders,
                                    dayState: key.dayState, sections: key.sections, context: context, dayOffset: dayOffset,
                                    eventsKnown: key.eventsKnown)
        plans[dayOffset] = CachedPlan(key: key, plan: plan)
        return plan
    }

    var problemCount: Int { tasks.fileProblems.count + plan(at: day.clock.now).problems.count }

    /// The widget snapshot and reload, and the notification schedule. The notification center can be slow to answer
    /// (or not answer at all in a broken simulator); nothing waits for it here.
    func publish() async {
        let context = day.context()
        if config.flags.widgetSnapshot {
            // The widget shows the next hours from this one snapshot, past the day boundary too.
            let rules = config.rules.widgets
            let reach = context.dayEnd.addingTimeInterval(Double(rules.entryCount * rules.refreshMinutes) * 60)
            let snapshot = WidgetSnapshot(generatedAt: context.now, tasks: tasks.tasks, events: sources.events,
                                          reminders: sources.reminders.filter { $0.due >= context.dayStart && $0.due < reach },
                                          dayState: day.dayState, eventsKnown: sources.eventsKnown)
            try? snapshotStore.save(snapshot)
        }
        widgets.reloadAll()
        queue.schedulePlan { [weak self] in await self?.reschedule(context: context) }
        mirrorToday()
    }

    /// The store's file looks as today does (`DayMirroring`).
    private func mirrorToday() {
        guard let mirroring else { return }
        let plan = plan(at: day.clock.now)
        let sections = plan.sections.map { section in
            DayMirror.Section(title: section.isCustom ? section.title : L10n.string(section.title),
                              names: section.items.filter { $0.depth == 0 }.map(\.id))
        }
        var timed: [String: LocalTime] = [:]
        for slot in plan.timeline {
            if case .task(let item) = slot.content { timed[item.id] = LocalTime(slot.start, in: day.calendar) }
        }
        let mirror = DayMirror(sections: sections, timed: timed, keptOut: day.postponedNames)
        Task { await mirroring.mirror(mirror) }
    }

    /// Only how things look changed: the widgets read that from the settings themselves.
    func reloadWidgets() {
        widgets.reloadAll()
    }

    /// The notifications planned again now (a new picture), in line with the other plans; returns when it is done.
    func replanNotifications() async {
        let context = day.context()
        queue.schedulePlan { [weak self] in await self?.reschedule(context: context) }
        await queue.waitUntilIdle()
    }

    /// A notification swiped away or tapped comes back (silently) while its day lasts, in line with the plans: a plan
    /// being scheduled finishes first, and a plan made after it waits, so a sync never takes away the request just put back.
    func restore(_ request: UNNotificationRequest) async {
        let day = (request.content.userInfo[NotificationPayload.dayKey] as? String).flatMap(LocalDate.init(isoString:))
        guard !StaleNotifications.isOver(day, today: self.day.context().today) else { return }
        let notifications = notifications
        await queue.run { await notifications.restore(request) }
    }

    /// A notification snoozed from its button leaves Notification Center and comes again after
    /// `notifications.snoozeMinutes`, while its day lasts and its item stays open. A task's or habit's block moves on
    /// today's timeline to that moment and its notification follows it (`NotificationSnoozing.moves`); an event's or
    /// reminder's notification just comes again (`NotificationSnooze`). Returns when the plan with it is scheduled, so the
    /// app is not suspended before.
    func snooze(key: String, day: LocalDate, shown identifier: String) async {
        let context = self.day.context()
        guard !StaleNotifications.isOver(day, today: context.today) else { return }
        let until = context.now.addingTimeInterval(Double(config.rules.notifications.snoozeMinutes) * 60)
        let inputs = notificationInputs(context: context)
        let snoozed = inputs.all().first { $0.key == key && $0.day == day }
        let task = snoozed?.taskName.flatMap { name in inputs.tasks.first { $0.name.isSameNoteName(as: name) } }
        if let snoozed, let task, let moves = NotificationSnoozing.moves(snoozing: snoozed, of: task, until: until,
                                                                         today: inputs.todayTimes, context: context) {
            self.day.setTimeMoves(moves)
            widgets.reloadAll()
        } else {
            let snooze = NotificationSnooze(key: key, day: day, until: until)
            try? snoozeStore.save(NotificationSnoozing.adding(snooze, to: snoozeStore.load(), today: context.today))
        }
        let notifications = notifications
        await queue.run { await notifications.remove(shown: identifier) }
        await replanNotifications()
    }

    /// A notification dismissed from its button leaves Notification Center; its item and the schedule stay as they are.
    func dismiss(shown identifier: String) async {
        let notifications = notifications
        await queue.run { await notifications.remove(shown: identifier) }
    }

    /// Background work waits for the notification schedule before the app is suspended.
    func waitForNotifications() async {
        await queue.waitUntilIdle()
    }

    /// How many notification jobs were put in line so far (tests watch a restore take its place).
    var notificationJobs: Int { queue.enqueued }

    private func reschedule(context: DayContext) async {
        let settings = settings.settings
        guard config.flags.notifications, settings.notifications.enabled else {
            await notifications.removeAll()
            return
        }
        let inputs = notificationInputs(context: context)
        let planned = inputs.planner.plan(tasks: inputs.tasks, reminders: inputs.reminders, events: inputs.events,
                                          skipped: inputs.skipped, todayTimes: inputs.todayTimes, context: context)
        let valid = inputs.planner.stillValidToday(tasks: inputs.tasks, reminders: inputs.reminders, events: inputs.events,
                                                   skipped: inputs.skipped, todayTimes: inputs.todayTimes, context: context)
        // Alerts moved into the past or added too late come right away, once.
        let all = inputs.all()
        let previous = alertStateStore.load()
        let late = LateAlerts.due(all, pending: previous?.pending ?? [:], known: previous.map { Set($0.known) }, context: context)
        try? alertStateStore.save(AlertState(
            pending: Dictionary(planned.map { ($0.key, $0.fireDate) }, uniquingKeysWith: min),
            known: Array(Set(all.map(\.key)))))
        let snoozed = NotificationSnoozing.notifications(currentSnoozes(today: context.today), valid: valid, context: context)
        await notifications.sync(planned: planned + snoozed.filter { $0.fireDate > context.now }, stillValid: valid + late + snoozed,
                                 now: late)
    }

    /// What the notifications are planned from now.
    private func notificationInputs(context: DayContext) -> NotificationInputs {
        let rules = config.rules.notifications
        let dayState = day.dayState
        let isToday = dayState.day == context.today
        // Skip today (habits) and Not today (tasks) both take an item out of today's notifications; blocks dragged or
        // snoozed today ring at their new time, or not at all from the pool. Times kept in a zone of their own ring at
        // the phone's time for that moment.
        return NotificationInputs(planner: NotificationPlanner(horizonDays: rules.horizonDays, limit: rules.limit),
                                  tasks: ZonedTimes.local(tasks.tasks, calendar: context.calendar, today: context.today),
                                  reminders: sources.reminders, events: sources.events,
                                  skipped: Set(isToday ? dayState.skipped + dayState.postponed : []),
                                  todayTimes: TodayTimes(isToday ? dayState.timeMoves : []), context: context)
    }

    /// The snoozes of today; those of days that are over are forgotten.
    private func currentSnoozes(today: LocalDate) -> [NotificationSnooze] {
        let stored = snoozeStore.load()
        let current = NotificationSnoozing.current(stored, today: today)
        if current.count != stored.count { try? snoozeStore.save(current) }
        return current
    }
}

/// The data one notification plan is made from.
private struct NotificationInputs {
    let planner: NotificationPlanner
    let tasks: [TaskItem]
    let reminders: [ReminderItem]
    let events: [CalendarEvent]
    let skipped: Set<String>
    let todayTimes: TodayTimes
    let context: DayContext

    /// Everything of today and the coming days, past times included.
    func all() -> [PlannedNotification] {
        planner.all(tasks: tasks, reminders: reminders, events: events, skipped: skipped, todayTimes: todayTimes, context: context)
    }
}
