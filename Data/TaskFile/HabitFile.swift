import Foundation

/// A habit's settings, a JSON file of its own named by its id in the habits folder (`task-file.json`). What it did each day
/// is not here: those are its lines in Done of the tasks file.
struct HabitFile: Codable, Equatable, Sendable {
    var id: String
    var name: String
    var isArchived = false
    /// The rule as text; one the app cannot read stays as it is and the habit shows a problem.
    var recurrence: String?
    var reminderTimes: [LocalTime] = []
    /// Which of its times ring as alarms (absent in older files).
    var alarms: [TimeAlarm]?
    var timeZone: String?
    /// An older habit's date and time, which its days may start from.
    var due: TaskDue?
    var options = HabitOptions()
    var isHighPriority = false
    var feel: TaskFeel = .neutral
    var timeEstimate: Int?
    /// The id of the habit it is a subtask of, and its place there.
    var parent: String?
    var order: Int?
    /// Older files only: where the rule's days start, until the rule says it itself.
    var created: LocalDate?
    /// Its text.
    var note: String = ""

    init(id: String, item: TaskItem, parent: String?, note: String) {
        self.id = id
        self.parent = parent
        self.note = note
        name = item.name
        update(from: item)
    }

    mutating func update(from item: TaskItem) {
        name = item.name
        isArchived = item.isArchived
        if let rule = item.recurrence {
            recurrence = RecurrenceCodec.format(rule.startDate == nil ? rule.starting(item.created?.day ?? item.due?.day ?? created) : rule)
        } else if !item.hasUnreadableRecurrence { recurrence = nil }
        reminderTimes = item.reminderTimes
        alarms = item.alarms.isEmpty ? nil : item.alarms
        timeZone = item.timeZone
        due = item.due
        options = item.habit
        isHighPriority = item.isHighPriority
        feel = item.feel
        timeEstimate = item.timeEstimate
        order = item.subtaskOrder
        created = nil
    }

    /// The habit as the app knows it, with its marks read from the tasks file.
    func item(parentName: String?, marks: [LocalDate: HabitMark]) -> TaskItem {
        var item = TaskItem(id: TaskID(id), name: name, status: isArchived ? .archived : .habit)
        item.isHighPriority = isHighPriority
        item.due = due
        item.timeEstimate = timeEstimate
        item.projects = parentName.map { [$0] } ?? []
        item.subtaskOrder = order
        item.feel = feel
        item.reminderTimes = reminderTimes
        item.alarms = alarms ?? []
        item.timeZone = timeZone
        item.habit = options
        item.marks = marks
        item.created = created.map { TaskDue(day: $0) }
        if let recurrence {
            switch RecurrenceCodec.parse(recurrence) {
            case .success(let rule): item.recurrence = rule.withoutEnd
            case .failure:
                item.hasUnreadableRecurrence = true
                item.problems.append(.unknownRecurrence(recurrence))
            }
        }
        return item
    }

    func text(pretty: Bool = true) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(self), as: UTF8.self) + "\n"
    }
}

extension TaskDocument {
    /// The marks a habit's lines in Done make: `[x]` done, two of them on one day Twice, `[/]` partial.
    func marks(of id: String) -> [LocalDate: HabitMark] {
        var counts: [LocalDate: (done: Int, partial: Int)] = [:]
        walk { entry, section, _, _ in
            guard section == .done, entry.id == id, let day = entry.completed else { return }
            switch entry.box {
            case .done: counts[day, default: (0, 0)].done += 1
            case .started: counts[day, default: (0, 0)].partial += 1
            case .open: break
            }
        }
        return counts.mapValues { $0.done >= 2 ? .twice : $0.done == 1 ? .done : .partial }
    }

    /// Writes one day's mark of a habit as its lines in Done, newest on top.
    mutating func setMark(_ mark: HabitMark?, on day: LocalDate, habit id: String, name: String) {
        while remove(where: { $0.id == id && $0.completed == day }) != nil {}
        guard let mark else { return }
        let line = { (box: TaskEntry.Box) in
            var entry = TaskEntry(box: box, name: name)
            entry.id = id
            entry.completed = day
            return entry
        }
        switch mark {
        case .done: insertMark(line(.done))
        case .partial: insertMark(line(.started))
        case .twice:
            insertMark(line(.done))
            insertMark(line(.done))
        }
    }

    private mutating func insertMark(_ entry: TaskEntry) {
        insert(entry, into: .done, atTop: true)
    }
}
