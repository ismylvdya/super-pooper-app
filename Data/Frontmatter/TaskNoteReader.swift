import Foundation

/// Reads a `TaskItem` from frontmatter using the field mapping. Missing fields get defaults;
/// unreadable ones become problems on the task instead of failures.
struct TaskNoteReader: Sendable {
    let mapping: FieldMapping
    let taskTag: String
    let calendar: Calendar

    func isTask(_ document: FrontmatterDocument) -> Bool {
        guard let value = try? document.value(for: mapping.fields.tags) else { return false }
        let wanted = normalizedTag(taskTag)
        return FieldValues.strings(value).contains { tag in
            let normalized = normalizedTag(tag)
            return normalized == wanted || normalized.hasPrefix(wanted + "/")
        }
    }

    func task(from document: FrontmatterDocument, name: String, relativePath: String) -> TaskItem {
        let settings = ItemSettingsProperty(mapping: mapping)
        var fields = FieldReader(document: document, settings: settings.values(in: document) ?? [:], field: mapping.field(forKey:))
        let keys = mapping.fields

        var task = TaskItem(id: TaskID(relativePath: relativePath), name: name,
                            status: fields.string(keys.status).map(mapping.status(fromRaw:)) ?? .other(""))
        task.isHighPriority = fields.string(keys.priority) == mapping.priorities.high
        task.timeZone = fields.string(keys.timeZone).flatMap { TimeZone(identifier: $0) == nil ? nil : $0 }
        // TaskNotes writes a clock time; a moment with an offset (a skill, another app) is moved to the item's clock.
        let dueCalendar = ZonedTimes.calendar(of: task, phone: calendar)
        task.due = fields.parsed(keys.due) { TaskDue(rawValue: $0) ?? TaskDue(moment: $0, in: dueCalendar) }
        task.timeEstimate = fields.int(keys.timeEstimate)
        task.previousTasks = fields.links(keys.previousTasks)
        task.projects = fields.links(keys.projects)
        task.subtaskOrder = fields.int(keys.subtaskOrder)
        task.previousEvent = fields.parsed(keys.previousEvent, EventLink.init(rawValue:))
        task.nextEvent = fields.parsed(keys.nextEvent, EventLink.init(rawValue:))
        task.feel = feel(&fields)
        if let raw = fields.string(keys.recurrence), !raw.trimmingCharacters(in: .whitespaces).isEmpty {
            switch RecurrenceCodec.parse(raw) {
            case .success(let rule): task.recurrence = rule
            case .failure:
                task.hasUnreadableRecurrence = true
                fields.problems.append(.unknownRecurrence(raw))
            }
        }
        task.marks = HabitInstances(complete: fields.dates(keys.completeInstances), partial: fields.dates(keys.partialInstances),
                                    twice: fields.dates(keys.twiceInstances)).marks
        task.reminderTimes = fields.times(keys.reminderTimes)
        task.habit = habitOptions(&fields)
        task.completedDate = fields.parsed(keys.completedDate, LocalDate.init(isoString:))
        if let created = fields.string(keys.dateCreated) {
            task.dateCreated = fields.moment(created, key: keys.dateCreated, calendar: calendar)
            task.created = TaskDue(writtenWallClockOf: created)
        }
        task.dateModified = fields.timestamp(keys.dateModified, calendar: calendar)
        task.problems = fields.problems
        return task
    }

    private func habitOptions(_ fields: inout FieldReader) -> HabitOptions {
        let keys = mapping.fields
        var options = HabitOptions()
        options.color = fields.string(keys.habitColor).flatMap { $0.isEmpty ? nil : $0 }
        options.harmful = fields.bool(keys.harmful) ?? false
        options.repeatable = fields.bool(keys.repeatable) ?? false
        options.showInToday = fields.bool(keys.showInToday) ?? true
        options.timeOfDay = fields.parsed(keys.timeOfDay, mapping.timeOfDay(fromRaw:))
        options.twiceADay = fields.bool(keys.twiceADay) ?? false
        options.twiceCountsDouble = fields.bool(keys.twiceCountsDouble) ?? false
        options.weeklyGoal = fields.int(keys.weeklyGoal)
        options.allowedSkips = fields.int(keys.allowedSkips)
        return options
    }

    /// `feel`, or for older notes `need_energy: true` (or `pleasant: false`) = needs energy, `pleasant: true` = pleasant.
    private func feel(_ fields: inout FieldReader) -> TaskFeel {
        if let feel = fields.parsed(mapping.fields.feel, mapping.feel(fromRaw:)) { return feel }
        return .legacy(needEnergy: fields.bool(mapping.legacyFields.needEnergy), pleasant: fields.bool(mapping.legacyFields.pleasant))
    }

    private func normalizedTag(_ tag: String) -> String {
        var text = tag.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        return text.lowercased()
    }
}

/// Typed access to frontmatter values that collects problems. The item settings JSON wins over a separate
/// key of the same name (older notes have only those).
private struct FieldReader {
    let document: FrontmatterDocument
    let settings: [String: YAMLValue]
    /// The domain field of a key, for the problems.
    let field: (String) -> TaskField?
    var problems: [TaskProblem] = []

    private mutating func problem(_ key: String, _ value: String) {
        guard let field = field(key) else { return }
        problems.append(.invalidValue(field: field, value: value))
    }

    mutating func value(_ key: String) -> YAMLValue? {
        if let value = settings[key] { return value == .null ? nil : value }
        do {
            guard let value = try document.value(for: key) else { return nil }
            if case .null = value { return nil }
            return value
        } catch {
            problem(key, document.rawValue(for: key) ?? "")
            return nil
        }
    }

    mutating func string(_ key: String) -> String? {
        guard let value = value(key) else { return nil }
        if let text = value.string { return text }
        if let first = value.list?.first?.string { return first }
        problem(key, document.rawValue(for: key) ?? "")
        return nil
    }

    mutating func parsed<T>(_ key: String, _ parse: (String) -> T?) -> T? {
        guard let text = string(key)?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        guard let result = parse(text) else {
            problem(key, text)
            return nil
        }
        return result
    }

    mutating func int(_ key: String) -> Int? {
        guard let value = value(key) else { return nil }
        guard let number = value.int ?? value.string.flatMap({ Double($0) }).map({ Int($0) }) else {
            problem(key, value.string ?? "")
            return nil
        }
        return number
    }

    mutating func bool(_ key: String) -> Bool? {
        guard let value = value(key) else { return nil }
        if let flag = value.bool ?? value.string.flatMap({ ["true": true, "false": false][$0.lowercased()] }) { return flag }
        problem(key, value.string ?? "")
        return nil
    }

    mutating func links(_ key: String) -> [String] {
        guard let value = value(key) else { return [] }
        let items = value.list ?? [value]
        return items.compactMap { item in
            let uid = item.value(for: "uid") ?? item
            return FieldValues.firstScalar(uid).flatMap(WikiLink.noteName(from:))
        }
    }

    mutating func dates(_ key: String) -> [LocalDate] {
        guard let value = value(key) else { return [] }
        var result: [LocalDate] = []
        for text in FieldValues.strings(value) {
            if let date = LocalDate(isoString: text) {
                if !result.contains(date) { result.append(date) }
            } else {
                problem(key, text)
            }
        }
        return result
    }

    mutating func times(_ key: String) -> [LocalTime] {
        guard let value = value(key) else { return [] }
        var result: [LocalTime] = []
        for text in FieldValues.strings(value) {
            if let time = LocalTime(string: text) {
                if !result.contains(time) { result.append(time) }
            } else {
                problem(key, text)
            }
        }
        return result.sorted()
    }

    mutating func timestamp(_ key: String, calendar: Calendar) -> Date? {
        guard let text = string(key) else { return nil }
        return moment(text, key: key, calendar: calendar)
    }

    mutating func moment(_ text: String, key: String, calendar: Calendar) -> Date? {
        if let date = ISO8601.parse(text) ?? WrittenTimestamp(text)?.moment { return date }
        if let day = LocalDate(isoString: text) {
            if text.count == 10 { return day.startDate(in: calendar) }
            if let due = TaskDue(rawValue: text) { return due.date(in: calendar) }
        }
        problem(key, text)
        return nil
    }
}

enum FieldValues {
    /// Scalars of a list, or the single scalar.
    static func strings(_ value: YAMLValue) -> [String] {
        if let items = value.list { return items.compactMap(firstScalar) }
        return value.string.map { [$0] } ?? []
    }

    /// An unquoted `[[Name]]` parses as nested lists; this digs the text back out.
    static func firstScalar(_ value: YAMLValue) -> String? {
        switch value {
        case .scalar(let text, _): return text
        case .list(let items):
            guard let inner = items.first.flatMap(firstScalar) else { return nil }
            if case .list = items.first { return "[[\(inner)]]" }
            return inner
        default: return nil
        }
    }
}
