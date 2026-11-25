import Foundation

/// The placement written for a task carried to a planning list, a day's pool or a scheduled time.
enum TaskPlacementMove {
    enum Destination {
        case list(TaskStatus)
        case pool(LocalDate, sectionTag: String?)
        case scheduled(Date)
    }

    static func changes(for task: TaskItem, to destination: Destination, fromScheduled: Bool, context: DayContext) -> [TaskEdit] {
        let marking = TaskMarking(today: context.today)
        switch destination {
        case .list(let status):
            var edits = marking.changes(setting: status, on: task)
            if task.due != nil, status.isThisWeek || fromScheduled { edits.append(.due(nil)) }
            return edits + outsidePool(task)
        case .pool(let day, let tag):
            var edits = marking.changes(setting: .thisWeek, on: task)
            if day == context.today {
                if fromScheduled, task.due != nil {
                    edits.append(.due(nil))
                } else {
                    edits += TaskScheduling.changes(unscheduling: task, context: context)
                }
                edits.append(.inTodayPool(true))
                if task.poolSection != tag { edits.append(.poolSection(tag)) }
            } else {
                if task.due != TaskDue(day: day) { edits.append(.due(TaskDue(day: day))) }
                edits += outsidePool(task)
                edits += intoPlannedDay(task, day: day, context: context)
            }
            return edits
        case .scheduled(let moment):
            return marking.changes(setting: .thisWeek, on: task)
                + TaskScheduling.changes(scheduling: task, at: moment, calendar: context.calendar)
                + outsidePool(task)
                + intoPlannedDay(task, day: context.logicalDay(of: moment), context: context)
        }
    }

    private static func intoPlannedDay(_ task: TaskItem, day: LocalDate, context: DayContext) -> [TaskEdit] {
        task.isNotTomorrow && day == context.today.adding(days: 1) ? [.notTomorrow(false)] : []
    }

    private static func outsidePool(_ task: TaskItem) -> [TaskEdit] {
        [.inTodayPool(false)] + (task.poolSection == nil ? [] : [.poolSection(nil)])
    }
}
