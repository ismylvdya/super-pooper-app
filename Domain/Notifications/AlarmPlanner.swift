import Foundation

/// An alarm the app wants to have set. `id` changes with anything about it, so a changed alarm is set anew.
struct PlannedAlarm: Hashable, Sendable {
    let id: String
    let title: String
    let fireDate: Date
    /// The sound's file; nil = the system's alarm sound.
    let soundFile: String?
    /// What its notification went by, for Snooze.
    let key: String
    let day: LocalDate
    /// The task or habit it rings for, for Done.
    let taskName: String?
}

/// Which planned notifications ring as alarms instead: an alarm has its own Stop and Snooze, so no notification goes with it.
struct AlarmPlanner: Sendable {
    let sounds: [RulesConfig.Alarms.Sound]
    /// The sound of alarms that have none of their own (the settings).
    let defaultSound: String

    /// The notifications left when alarms ring instead of theirs.
    func withoutAlarmed(_ planned: [PlannedNotification], tasks: [TaskItem]) -> [PlannedNotification] {
        planned.filter { alarm(of: $0, tasks: tasks) == nil }
    }

    func alarms(_ planned: [PlannedNotification], tasks: [TaskItem]) -> [PlannedAlarm] {
        planned.compactMap { notification in
            guard let alarm = alarm(of: notification, tasks: tasks) else { return nil }
            let sound = alarm.sound ?? defaultSound
            let file = sounds.first { $0.id == sound }?.file
            let id = [notification.key, notification.day.isoString, "\(notification.fireDate.timeIntervalSince1970)", notification.title,
                      file ?? ""].joined(separator: "|")
            return PlannedAlarm(id: id, title: notification.title, fireDate: notification.fireDate, soundFile: file,
                                key: notification.key, day: notification.day, taskName: notification.taskName)
        }
    }

    private func alarm(of notification: PlannedNotification, tasks: [TaskItem]) -> TimeAlarm? {
        guard [.habit, .task].contains(notification.kind), let name = notification.taskName else { return nil }
        return tasks.first { $0.name.isSameNoteName(as: name) }?.alarm(at: notification.slot)
    }
}

/// Alarms behind a protocol (the planner decides what, this only talks to iOS).
protocol AlarmScheduling: Sendable {
    /// False when the user refused them.
    func requestAccess() async -> Bool
    /// Alarms can ring now.
    var isAuthorized: Bool { get }
    /// Makes the alarms set equal to `alarms`.
    func sync(_ alarms: [PlannedAlarm]) async
}

/// Where there are no alarms (previews, tests).
struct NoAlarms: AlarmScheduling {
    var isAuthorized: Bool { false }
    func requestAccess() async -> Bool { true }
    func sync(_ alarms: [PlannedAlarm]) async {}
}
