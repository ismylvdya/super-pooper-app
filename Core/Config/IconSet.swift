import Foundation

/// Names of every SF Symbol used outside the action registry (`icons.json`).
enum Icon: String, CaseIterable, Sendable {
    case settings, review, more, info, problem, sync
    case energy, pleasant, high, due, time, estimate, blocked
    case previousTasks, nextTasks, previousEvent, nextEvent, event, reminder, habit
    case vault, calendars, reminderLists, notifications
    case dayBoundary, energyHour, timelineLayout, hoursAfter, hoursBefore, halves, fontSize, poolCount
    case archive, delete, edit, version, search, resetOrder, add, newTask, colors, remove, chevron, status, note, title, recurrence
    case checkboxOpen, markDone, markPartial, markTwice
    case emptyVault, debugSeed, permissionGranted, permissionMissing
    case tabToday, tabHabits, tabSettings
    case bell, olderWeeks
    case today, harmful, timeOfDay, goal, trash, restore, links, opacity, obsidian, habitSettings, taskSettings, clockSettings
}

typealias IconSet = TokenTable<Icon, String>
