import Foundation

/// Names of every SF Symbol used outside the action registry (`icons.json`).
enum Icon: String, CaseIterable, Codable, Sendable {
    case settings, review, more, info, problem, sync
    case energy, pleasant, high, due, time, estimate
    case previousTasks, nextTasks, previousEvent, nextEvent, event, reminder, habit
    case vault, calendars, reminderLists, notifications
    case dayBoundary, energyHour, timelineLayout, hoursAfter, hoursBefore, halves, fontSize, poolCount
    case archive, delete, search, resetOrder, resetSort, add, newTask, colors, remove, chevron, status, note, title, recurrence
    case checkboxOpen, markDone
    case emptyVault, debugSeed, permissionGranted
    case tabToday, tabHabits, tabLists, tabSettings
    case listQuick, listThisWeek, listHalfYear, listSomeday, listWaiting, listDone, listArchived, inboxShortcut
    case bell, olderWeeks, postpone
    /// Asset catalog template images (not SF Symbols): the habit marks, shared by menus and notifications.
    case habitMarkOpen, habitMarkDone, habitMarkPartial, habitMarkTwice
    case today, harmful, timeOfDay, goal, trash, restore, links, opacity, obsidian, habitSettings, taskSettings, clockSettings
    case tomorrow, subtask, addSubtask, selected, previousDay, nextDay
}

typealias IconSet = TokenTable<Icon, String>

extension TokenTable where Key == Icon, Value == String {
    /// `"7.calendar|calendar"`: the first symbol the system has, so a newer SF Symbol can have a fallback on an
    /// older iOS. A single name is kept as it is.
    func resolvingFallbacks(isAvailable: (String) -> Bool) -> IconSet {
        replacing(Dictionary(uniqueKeysWithValues: Icon.allCases.map { key in
            let candidates = self[key].split(separator: "|").map(String.init)
            return (key, candidates.first(where: isAvailable) ?? candidates.last ?? self[key])
        }))
    }
}
