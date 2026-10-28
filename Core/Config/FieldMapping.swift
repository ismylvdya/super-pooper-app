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
        /// How doing the task feels (`feels` values; absent = neutral).
        let feel: String
        let recurrence: String
        let completeInstances: String
        let partialInstances: String
        let twiceInstances: String
        let completedDate: String
        let dateCreated: String
        let dateModified: String
        let reminderTimes: String
        /// The zone of the item's times (an app setting of the item, in its JSON).
        let timeZone: String
        let habitColor: String
        let harmful: String
        let repeatable: String
        let showInToday: String
        let timeOfDay: String
        let twiceADay: String
        let twiceCountsDouble: String
        let weeklyGoal: String
        let allowedSkips: String
        /// A subtask's place among its parent's subtasks (set by dragging them on the parent's page).
        let subtaskOrder: String
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

    /// Raw values of `feel`.
    struct Feels: Codable, Hashable, Sendable {
        let needEnergy: String
        let pleasant: String
    }

    /// Keys of older notes, read and rewritten into the current fields: `need_energy`/`pleasant` booleans became `feel`.
    struct LegacyFields: Codable, Hashable, Sendable {
        let needEnergy: String
        let pleasant: String
    }

    struct Priorities: Codable, Hashable, Sendable {
        let high: String
        let normal: String
    }

    /// The app's own settings of an item, kept together in one JSON property (see `ItemSettingsProperty`).
    struct ItemSettings: Codable, Hashable, Sendable {
        let property: String
        /// Earlier names of the property, read when the current one is missing and removed on the next write.
        let legacyProperties: [String]
        /// Names in `fields` (`habitColor`, `showInToday` …) of the settings that go into it.
        let fields: [String]
    }

    let fields: Fields
    let statuses: Statuses
    let priorities: Priorities
    let timesOfDay: TimesOfDay
    let feels: Feels
    let legacyFields: LegacyFields
    let itemSettings: ItemSettings
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

    func feel(fromRaw raw: String) -> TaskFeel? {
        switch raw {
        case feels.needEnergy: .needEnergy
        case feels.pleasant: .pleasant
        default: nil
        }
    }

    /// nil = neutral, which is no value.
    func raw(_ feel: TaskFeel) -> String? {
        switch feel {
        case .needEnergy: feels.needEnergy
        case .pleasant: feels.pleasant
        case .neutral: nil
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

    /// Every name in `itemSettings.fields` must be a field, so a typo stops the app instead of losing a setting.
    func validate(file: String) throws {
        if itemSettingsKeys.count != Set(itemSettings.fields).count {
            throw ConfigError(file: file, path: "itemSettings.fields", message: "a name that is not in \"fields\"")
        }
    }

    /// Frontmatter key names of the item settings, e.g. `habit_color`.
    var itemSettingsKeys: Set<String> {
        guard let data = try? JSONEncoder().encode(fields),
              let names = (try? JSONSerialization.jsonObject(with: data)) as? [String: String] else { return [] }
        return Set(itemSettings.fields.compactMap { names[$0] })
    }
}
