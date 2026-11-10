import Foundation

extension TaskEntry {
    /// The task as the app knows it. `section`: where the line stands, which with its checkbox gives the status.
    /// `follows`: the parent's day, for a subtask with no date of its own.
    /// `list`: the heading it stands under in Lists.
    func item(in section: TaskSection, list: String? = nil, parentName: String?, order: Int?, follows: LocalDate? = nil,
              format: TaskFileFormat) -> TaskItem {
        var item = TaskItem(id: TaskID(id ?? ""), name: name, status: status(in: section, list: list))
        item.isHighPriority = isHigh
        item.stepsOneByOne = stepsOneByOne
        item.due = date.map { TaskDue(day: $0, time: time) } ?? follows.map { TaskDue(day: $0) }
        item.timeEstimate = estimate
        item.alarms = alarm.map { [TimeAlarm(sound: $0 == format.alarmDefaultSound ? nil : $0)] } ?? []
        item.projects = parentName.map { [$0] } ?? []
        item.subtaskOrder = order
        item.feel = feel
        item.timeZone = zone
        item.completedDate = completed
        item.isOverdue = isOverdue
        item.isStarted = box == .started
        item.waitsInList = section == .soon && item.due == nil
        return item
    }

    /// The line with its parent's date and time when it has none of its own: where a subtask without a date stands.
    func following(_ parent: TaskEntry?) -> TaskEntry {
        guard date == nil, let parent else { return self }
        var line = self
        line.date = parent.date
        line.time = parent.time
        return line
    }

    /// A line in Lists outside every list's heading waits in Someday.
    private func status(in section: TaskSection, list: String?) -> TaskStatus {
        if box == .done || section == .done { return .done }
        switch section {
        case .now, .soon: return .thisWeek
        case .halfYear: return .halfYear
        case .someday: return .someday
        case .lists: return list.map(TaskStatus.custom) ?? .someday
        case .archive: return .archived
        case .done, .trash: return .done
        }
    }

    /// Takes on the fields of `item`; the line's text and subtasks stay. The section follows from `TaskSection.of`.
    mutating func update(from item: TaskItem, format: TaskFileFormat) {
        name = item.name
        box = item.status == .done ? .done : item.isStarted ? .started : .open
        isHigh = item.isHighPriority
        stepsOneByOne = item.stepsOneByOne
        date = item.due?.day
        time = item.due?.time
        estimate = item.timeEstimate
        alarm = item.alarms.first.map { $0.sound ?? format.alarmDefaultSound }
        feel = item.feel
        zone = item.timeZone
        completed = item.completedDate
        isOverdue = item.isOverdue
    }
}

extension TaskSection {
    /// Where a task of that status stands. This week's: Today from its day on, otherwise Next actions, undated too.
    static func of(_ item: TaskItem, current: TaskSection, today: LocalDate, boundary: LocalTime = .midnight) -> TaskSection {
        switch item.status {
        case .thisWeek:
            guard let day = item.due?.logicalDay(boundary: boundary) else { return .soon }
            return day > today ? .soon : .now
        case .halfYear: return .halfYear
        case .someday: return .someday
        case .custom: return .lists
        case .archived: return .archive
        // A done task stays where it is until it is put away, and then it is in Done already.
        case .done: return current
        case .habit: return .now
        }
    }
}
