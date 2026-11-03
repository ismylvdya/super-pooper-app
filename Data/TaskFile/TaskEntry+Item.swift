import Foundation

extension TaskEntry {
    /// The task as the app knows it. `section`: where the line stands, which with its checkbox gives the status.
    func item(in section: TaskSection, parentName: String?, order: Int?) -> TaskItem {
        var item = TaskItem(id: TaskID(id ?? ""), name: name, status: status(in: section))
        item.isHighPriority = isHigh
        item.due = date.map { TaskDue(day: $0, time: time) }
        item.timeEstimate = estimate
        item.projects = parentName.map { [$0] } ?? []
        item.subtaskOrder = order
        item.feel = feel
        item.timeZone = zone
        item.completedDate = completed
        item.created = created.map { TaskDue(day: $0) }
        return item
    }

    private func status(in section: TaskSection) -> TaskStatus {
        if box == .done || section == .done { return .done }
        switch section {
        case .inbox: return .inbox
        case .now, .soon: return box == .started ? .inProgress : .thisWeek
        case .halfYear: return .halfYear
        case .someday: return .someday
        case .waiting: return .waiting
        case .archive: return .archived
        case .done, .trash: return .done
        }
    }

    /// Takes on the fields of `item`; the line's text and subtasks stay. The section follows from `TaskSection.of`.
    mutating func update(from item: TaskItem) {
        name = item.name
        box = item.status == .done ? .done : item.status.isStarted ? .started : .open
        isHigh = item.isHighPriority
        date = item.due?.day
        time = item.due?.time
        estimate = item.timeEstimate
        feel = item.feel
        zone = item.timeZone
        completed = item.completedDate
    }
}

extension TaskSection {
    /// Where a task of that status stands. This week's: Soon while dated later than `today`, Now from its day on; undated
    /// where it stands (a task kept out of today waits in Soon).
    static func of(_ item: TaskItem, current: TaskSection, today: LocalDate) -> TaskSection {
        switch item.status.planningLevel {
        case .inbox: return .inbox
        case .thisWeek:
            guard let day = item.due?.day else { return current == .soon ? .soon : .now }
            return day > today ? .soon : .now
        case .halfYear: return .halfYear
        case .someday: return .someday
        case .waiting: return .waiting
        case .archived: return .archive
        // A done task stays where it is until it is put away, and then it is in Done already.
        case .done: return current
        case .habit, .inProgress, .other: return .now
        }
    }
}
