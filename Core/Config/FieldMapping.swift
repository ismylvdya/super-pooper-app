import Foundation

/// TaskNotes field names and status values (`field-mapping.json`).
/// Renaming a field in TaskNotes = changing one line there.
struct FieldMapping: Codable, Hashable, Sendable {
    struct Fields: Codable, Hashable, Sendable {
        let tags: String
        let status: String
        let priority: String
        let due: String
        let timeEstimate: String
        let previousTasks: String
        /// TaskNotes subtasks: a subtask lists its parent notes here.
        let projects: String
        let previousEvent: String
        let nextEvent: String
        let needEnergy: String
        let pleasant: String
        let recurrence: String
        let completeInstances: String
        let partialInstances: String
        let twiceInstances: String
        let completedDate: String
        let dateCreated: String
        let dateModified: String
        let reminderTimes: String
        let habitColor: String
        let harmful: String
        let showInToday: String
        let timeOfDay: String
        let twiceADay: String
        let twiceCountsDouble: String
        let weeklyGoal: String
        let allowedSkips: String
    }

    /// Raw values of `time_of_day`.
    struct TimesOfDay: Codable, Hashable, Sendable {
        let morning: String
        let day: String
        let evening: String
    }

    struct Statuses: Codable, Hashable, Sendable {
        let thisWeek: String
        let halfYear: String
        let someday: String
        let waiting: String
        let done: String
        let archived: String
        let habit: String
    }

    struct Priorities: Codable, Hashable, Sendable {
        let high: String
        let normal: String
    }

    let fields: Fields
    let statuses: Statuses
    let priorities: Priorities
    let timesOfDay: TimesOfDay
    /// `reltype` written into new `previous_task` entries.
    let dependencyRelType: String

    func status(fromRaw raw: String) -> TaskStatus {
        switch raw {
        case statuses.thisWeek: .thisWeek
        case statuses.halfYear: .halfYear
        case statuses.someday: .someday
        case statuses.waiting: .waiting
        case statuses.done: .done
        case statuses.archived: .archived
        case statuses.habit: .habit
        default: .other(raw)
        }
    }

    func timeOfDay(fromRaw raw: String) -> HabitTimeOfDay? {
        switch raw {
        case timesOfDay.morning: .morning
        case timesOfDay.day: .day
        case timesOfDay.evening: .evening
        default: nil
        }
    }

    func raw(_ timeOfDay: HabitTimeOfDay) -> String {
        switch timeOfDay {
        case .morning: timesOfDay.morning
        case .day: timesOfDay.day
        case .evening: timesOfDay.evening
        }
    }

    func raw(_ status: TaskStatus) -> String {
        switch status {
        case .thisWeek: statuses.thisWeek
        case .halfYear: statuses.halfYear
        case .someday: statuses.someday
        case .waiting: statuses.waiting
        case .done: statuses.done
        case .archived: statuses.archived
        case .habit: statuses.habit
        case .other(let raw): raw
        }
    }
}
