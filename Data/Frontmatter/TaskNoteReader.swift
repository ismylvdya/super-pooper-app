import Foundation

/// Reads a `TaskNote` from frontmatter using the field mapping. Missing fields get defaults;
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

    func task(from document: FrontmatterDocument, name: String, relativePath: String) -> TaskNote {
        let settings = ItemSettingsProperty(property: mapping.itemSettings.property, keys: mapping.itemSettingsKeys)
        var fields = FieldReader(document: document, settings: settings.values(in: document) ?? [:])
        let keys = mapping.fields

        var task = TaskNote(name: name, relativePath: relativePath,
                            status: fields.string(keys.status).map(mapping.status(fromRaw:)) ?? .other(""))
        task.isHighPriority = fields.string(keys.priority) == mapping.priorities.high
        task.due = fields.parsed(keys.due, TaskDue.init(rawValue:))
        task.timeEstimate = fields.int(keys.timeEstimate)
        task.previousTasks = fields.links(keys.previousTasks)
        task.projects = fields.links(keys.projects)
        task.subtaskOrder = fields.int(keys.subtaskOrder)
        task.previousEvent = fields.parsed(keys.previousEvent, EventLink.init(rawValue:))
        task.nextEvent = fields.parsed(keys.nextEvent, EventLink.init(rawValue:))
        task.needEnergy = fields.bool(keys.needEnergy) ?? false
        task.pleasant = fields.bool(keys.pleasant)
        if let raw = fields.string(keys.recurrence), !raw.trimmingCharacters(in: .whitespaces).isEmpty {
            task.recurrenceRaw = raw
            switch RecurrenceRule.parse(raw) {
            case .success(let rule): task.recurrence = rule
            case .failure: fields.problems.append(.unknownRecurrence(raw))
            }
        }
        task.completeInstances = fields.dates(keys.completeInstances)
        task.partialInstances = fields.dates(keys.partialInstances)
        task.twiceInstances = fields.dates(keys.twiceInstances)
        task.reminderTimes = fields.times(keys.reminderTimes)
        task.habit = habitOptions(&fields)
        task.completedDate = fields.parsed(keys.completedDate, LocalDate.init(isoString:))
        task.dateCreated = fields.timestamp(keys.dateCreated, calendar: calendar)
        task.dateModified = fields.timestamp(keys.dateModified, calendar: calendar)
        task.problems = fields.problems
        return task
    }

    private func habitOptions(_ fields: inout FieldReader) -> HabitOptions {
        let keys = mapping.fields
        var options = HabitOptions()
        options.color = fields.string(keys.habitColor).flatMap { $0.isEmpty ? nil : $0 }
        options.harmful = fields.bool(keys.harmful) ?? false
        options.showInToday = fields.bool(keys.showInToday) ?? true
        options.timeOfDay = fields.parsed(keys.timeOfDay, mapping.timeOfDay(fromRaw:))
        options.twiceADay = fields.bool(keys.twiceADay) ?? false
        options.twiceCountsDouble = fields.bool(keys.twiceCountsDouble) ?? false
        options.weeklyGoal = fields.int(keys.weeklyGoal)
        options.allowedSkips = fields.int(keys.allowedSkips)
        return options
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
    var problems: [TaskProblem] = []

    mutating func value(_ key: String) -> YAMLValue? {
        if let value = settings[key] { return value == .null ? nil : value }
        do {
            guard let value = try document.value(for: key) else { return nil }
            if case .null = value { return nil }
            return value
        } catch {
            problems.append(.invalidField(key: key, value: document.rawValue(for: key) ?? ""))
            return nil
        }
    }

    mutating func string(_ key: String) -> String? {
        guard let value = value(key) else { return nil }
        if let text = value.string { return text }
        if let first = value.list?.first?.string { return first }
        problems.append(.invalidField(key: key, value: document.rawValue(for: key) ?? ""))
        return nil
    }

    mutating func parsed<T>(_ key: String, _ parse: (String) -> T?) -> T? {
        guard let text = string(key)?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        guard let result = parse(text) else {
            problems.append(.invalidField(key: key, value: text))
            return nil
        }
        return result
    }

    mutating func int(_ key: String) -> Int? {
        guard let value = value(key) else { return nil }
        guard let number = value.int ?? value.string.flatMap({ Double($0) }).map({ Int($0) }) else {
            problems.append(.invalidField(key: key, value: value.string ?? ""))
            return nil
        }
        return number
    }

    mutating func bool(_ key: String) -> Bool? {
        guard let value = value(key) else { return nil }
        if let flag = value.bool ?? value.string.flatMap({ ["true": true, "false": false][$0.lowercased()] }) { return flag }
        problems.append(.invalidField(key: key, value: value.string ?? ""))
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
                problems.append(.invalidField(key: key, value: text))
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
                problems.append(.invalidField(key: key, value: text))
            }
        }
        return result.sorted()
    }

    mutating func timestamp(_ key: String, calendar: Calendar) -> Date? {
        guard let text = string(key) else { return nil }
        if let date = ISO8601.parse(text) { return date }
        if let day = LocalDate(isoString: text) {
            if text.count == 10 { return day.startDate(in: calendar) }
            if let due = TaskDue(rawValue: text) { return due.date(in: calendar) }
        }
        problems.append(.invalidField(key: key, value: text))
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
