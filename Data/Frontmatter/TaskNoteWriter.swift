import Foundation

/// Writes field changes into frontmatter, one key per change, plus `date_modified`
/// (formatted like TaskNotes: `2026-10-22T18:01:02.456+02:00`). Everything else stays untouched.
struct TaskNoteWriter: Sendable {
    let mapping: FieldMapping
    let timeZone: TimeZone

    func apply(_ changes: [TaskFieldChange], to document: inout FrontmatterDocument, now: Date) {
        let keys = mapping.fields
        for change in changes {
            switch change {
            case .status(let status):
                document.set(keys.status, to: .string(mapping.raw(status)))
            case .highPriority(let isHigh):
                document.set(keys.priority, to: .string(isHigh ? mapping.priorities.high : mapping.priorities.normal))
            case .due(let due):
                set(keys.due, due.map { .scalar($0.rawValue, quoted: false) }, in: &document)
            case .timeEstimate(let minutes):
                set(keys.timeEstimate, minutes.map(YAMLValue.int), in: &document)
            case .previousTasks(let names):
                setPreviousTasks(names, in: &document)
            case .previousEvent(let link):
                set(keys.previousEvent, link.map { .scalar($0.rawValue(timeZone: timeZone), quoted: true) }, in: &document)
            case .nextEvent(let link):
                set(keys.nextEvent, link.map { .scalar($0.rawValue(timeZone: timeZone), quoted: true) }, in: &document)
            case .needEnergy(let value):
                document.set(keys.needEnergy, to: .bool(value))
            case .pleasant(let value):
                set(keys.pleasant, value.map(YAMLValue.bool), in: &document)
            case .habitInstances(let instances):
                setDates(instances.complete, key: keys.completeInstances, keepEmpty: true, in: &document)
                setDates(instances.partial, key: keys.partialInstances, keepEmpty: false, in: &document)
                setDates(instances.twice, key: keys.twiceInstances, keepEmpty: false, in: &document)
            case .completedDate(let day):
                set(keys.completedDate, day.map { .scalar($0.isoString, quoted: false) }, in: &document)
            }
        }
        document.set(keys.dateModified, to: .scalar(ISO8601.formatWithMilliseconds(now, timeZone: timeZone), quoted: false))
    }

    private func set(_ key: String, _ value: YAMLValue?, in document: inout FrontmatterDocument) {
        if let value { document.set(key, to: value) } else { document.remove(key) }
    }

    /// Only lists that actually change are rewritten.
    private func setDates(_ days: [LocalDate], key: String, keepEmpty: Bool, in document: inout FrontmatterDocument) {
        let current = (try? document.value(for: key)).flatMap { $0 }.map(FieldValues.strings) ?? []
        let wanted = days.map(\.isoString)
        guard current != wanted || (days.isEmpty && !keepEmpty && document.keys.contains(key)) else { return }
        if days.isEmpty, !keepEmpty {
            document.remove(key)
        } else {
            document.set(key, to: .list(days.map { .scalar($0.isoString, quoted: false) }))
        }
    }

    /// Kept entries stay exactly as they were (custom `reltype`, `gap`); new ones are written the
    /// TaskNotes way: `{uid: "[[Name]]", reltype: FINISHTOSTART}`.
    private func setPreviousTasks(_ names: [String], in document: inout FrontmatterDocument) {
        let key = mapping.fields.previousTasks
        guard !names.isEmpty else {
            document.remove(key)
            return
        }
        let existing = (try? document.value(for: key)).flatMap { $0 }.map { $0.list ?? [$0] } ?? []
        var byName: [String: YAMLValue] = [:]
        for entry in existing {
            let uid = entry.value(for: "uid") ?? entry
            if let name = FieldValues.firstScalar(uid).flatMap(WikiLink.noteName(from:)), byName[name] == nil {
                byName[name] = entry
            }
        }
        let entries = names.map { name in
            byName[name] ?? .map([
                YAMLMapEntry(key: "uid", value: .scalar(WikiLink.make(name), quoted: true)),
                YAMLMapEntry(key: "reltype", value: .scalar(mapping.dependencyRelType, quoted: false)),
            ])
        }
        document.set(key, to: .list(entries))
    }
}
