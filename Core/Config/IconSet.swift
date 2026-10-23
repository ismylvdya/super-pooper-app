import Foundation

/// Names of every SF Symbol used outside the action registry (`icons.json`).
enum Icon: String, CaseIterable, Sendable {
    case settings, review, more, info, problem, sync
    case energy, pleasant, high, due, time, estimate, blocked
    case previousTasks, nextTasks, previousEvent, nextEvent, event, reminder, habit
    case vault, calendars, reminderLists, notifications
    case dayBoundary, energyHour, timelineLayout, hoursAfter, hoursBefore, halves, fontSize, poolCount
    case archive, version, search, resetOrder, add, remove, chevron, status, note, title, recurrence
    case checkboxOpen, markDone, markPartial, markTwice
    case emptyVault, debugSeed, permissionGranted, permissionMissing
}

typealias IconSet = TokenTable<Icon, String>
