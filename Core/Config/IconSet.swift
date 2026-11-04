import Foundation

/// Names of every SF Symbol used outside the action registry (`icons.json`), or of a hand-drawn template image of the
/// asset catalog (the Lists glyphs, the frog of Need energy, the habit marks).
enum Icon: String, CaseIterable, Codable, Sendable {
    case settings, more, info, problem, sync
    case tabBarSettings, plainTaskSettings, overdue, energy, pleasant, feel, chipOrder, timeZone, high, due, datePick, time, estimate
    case previousTasks, nextTasks, previousEvent, nextEvent, event, reminder, habit
    case vault, calendars, reminderLists, notifications, allDayEvent, alarm, alarmOn, stopAlarm, chosen
    case dayBoundary, energyHour, timelineLayout, hoursAfter, hoursBefore, halves, fontSize, poolCount
    case archive, delete, search, resetOrder, resetSort, add, newItem, colors, remove, chevron, status, note, title, recurrence
    case checkboxOpen, markDone
    case emptyVault, debugSeed, permissionGranted
    case tabToday, tabHabits, tabSettings
    /// The hand-drawn glyphs the Lists icon is picked from (Settings → Lists, `lists.json` → `icons`).
    case listsGun, listsGunFill, listsDoubleGuns, listsDoubleGunsFillForward, listsDoubleGunsFillBack
    case listQuick, listInbox, listThisWeek, listHalfYear, listSomeday, listWaiting, listDone, listArchived
    case bell, olderWeeks, postpone
    /// Asset catalog template images (not SF Symbols): the habit marks, shared by menus and notifications.
    case habitMarkOpen, habitMarkDone, habitMarkPartial, habitMarkTwice
    case today, harmful, timeOfDay, goal, trash, restore, links, opacity, obsidian, habitSettings, taskSettings, clockSettings
    case tomorrow, subtask, addSubtask, selected, previousDay, nextDay
    /// A pool row in Select mode, picked or not, and the mode's Cancel lying sideways.
    case themeLight, themeDark, selectCancel
    case syncAdded, syncChanged, syncRemoved, signing, snooze
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
