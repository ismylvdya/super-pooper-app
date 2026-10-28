import Foundation

/// Writes field changes into frontmatter, one key per change, plus `date_modified`
/// (formatted like TaskNotes: `2026-10-22T18:01:02.456+02:00`). Everything else stays untouched.
/// List changes are deltas applied to the lists as they are in the file right now.
struct TaskNoteWriter: Sendable {
    let mapping: FieldMapping
    let timeZone: TimeZone
    private let settings: ItemSettingsProperty

    init(mapping: FieldMapping, timeZone: TimeZone) {
        self.mapping = mapping
        self.timeZone = timeZone
        settings = ItemSettingsProperty(mapping: mapping)
    }

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
            case .addPreviousTask(let name):
                var entries = listItems(keys.previousTasks, in: document)
                guard !entries.contains(where: { linkName($0)?.isSameNoteName(as: name) == true }) else { continue }
                entries.append(newLink(to: name))
                document.set(keys.previousTasks, to: .list(entries))
            case .removePreviousTask(let name):
                let entries = listItems(keys.previousTasks, in: document)
                let kept = entries.filter { linkName($0)?.isSameNoteName(as: name) != true }
                guard kept.count != entries.count else { continue }
                set(keys.previousTasks, kept.isEmpty ? nil : .list(kept), in: &document)
            case .renamePreviousTask(let old, let new):
                let entries = listItems(keys.previousTasks, in: document)
                let renamed = entries.map { linkName($0)?.isSameNoteName(as: old) == true ? relink($0, to: new) : $0 }
                guard renamed != entries else { continue }
                document.set(keys.previousTasks, to: .list(renamed))
            case .addProject(let name):
                var entries = listItems(keys.projects, in: document)
                guard !entries.contains(where: { linkName($0)?.isSameNoteName(as: name) == true }) else { continue }
                entries.append(.scalar(WikiLink.make(name), quoted: true))
                document.set(keys.projects, to: .list(entries))
            case .renameProject(let old, let new):
                let entries = listItems(keys.projects, in: document)
                let renamed = entries.map { linkName($0)?.isSameNoteName(as: old) == true ? .scalar(WikiLink.make(new), quoted: true) : $0 }
                guard renamed != entries else { continue }
                document.set(keys.projects, to: .list(renamed))
            case .previousEvent(let link):
                set(keys.previousEvent, link.map { .scalar($0.rawValue(timeZone: timeZone), quoted: true) }, in: &document)
            case .nextEvent(let link):
                set(keys.nextEvent, link.map { .scalar($0.rawValue(timeZone: timeZone), quoted: true) }, in: &document)
            case .feel(let value):
                setFeel(value, in: &document)
            case .migrateLegacyFields:
                settings.migrate(in: &document)
                if hasLegacyFeel(document), (try? document.value(for: keys.feel)).flatMap({ $0 }) == nil {
                    setFeel(.legacy(needEnergy: bool(mapping.legacyFields.needEnergy, in: document),
                                    pleasant: bool(mapping.legacyFields.pleasant, in: document)), in: &document)
                } else {
                    document.remove(mapping.legacyFields.needEnergy)
                    document.remove(mapping.legacyFields.pleasant)
                }
            case .markInstance(let day, let mark):
                setInstance(day, included: mark != nil, key: keys.completeInstances, keepEmpty: true, in: &document)
                setInstance(day, included: mark == .partial, key: keys.partialInstances, keepEmpty: false, in: &document)
                setInstance(day, included: mark == .twice, key: keys.twiceInstances, keepEmpty: false, in: &document)
            case .completedDate(let day):
                set(keys.completedDate, day.map { .scalar($0.isoString, quoted: false) }, in: &document)
            case .recurrence(let raw):
                set(keys.recurrence, raw.map { .scalar($0, quoted: false) }, in: &document)
            case .reminderTimes(let times):
                set(keys.reminderTimes, times.isEmpty ? nil : .list(times.sorted().map { .string($0.string) }), in: &document)
            case .timeZone(let id):
                set(keys.timeZone, id.map { .scalar($0, quoted: true) }, in: &document)
            case .habitColor(let hex):
                set(keys.habitColor, hex.map { .scalar($0, quoted: true) }, in: &document)
            case .harmful(let value):
                set(keys.harmful, value ? .bool(true) : nil, in: &document)
            case .repeatable(let value):
                set(keys.repeatable, value ? .bool(true) : nil, in: &document)
            case .showInToday(let value):
                set(keys.showInToday, .bool(value), in: &document)
            case .timeOfDay(let value):
                set(keys.timeOfDay, value.map { .string(mapping.raw($0)) }, in: &document)
            case .twiceADay(let value):
                set(keys.twiceADay, value ? .bool(true) : nil, in: &document)
            case .twiceCountsDouble(let value):
                set(keys.twiceCountsDouble, value ? .bool(true) : nil, in: &document)
            case .weeklyGoal(let value):
                set(keys.weeklyGoal, value.map(YAMLValue.int), in: &document)
            case .allowedSkips(let value):
                set(keys.allowedSkips, value.map(YAMLValue.int), in: &document)
            case .subtaskOrder(let value):
                set(keys.subtaskOrder, value.map(YAMLValue.int), in: &document)
            }
        }
        document.set(keys.dateModified, to: .scalar(ISO8601.formatWithMilliseconds(now, timeZone: timeZone), quoted: false))
    }

    /// `feel` replaces the older `need_energy` and `pleasant` keys.
    private func setFeel(_ feel: TaskFeel, in document: inout FrontmatterDocument) {
        set(mapping.fields.feel, mapping.raw(feel).map { .string($0) }, in: &document)
        document.remove(mapping.legacyFields.needEnergy)
        document.remove(mapping.legacyFields.pleasant)
    }

    private func bool(_ key: String, in document: FrontmatterDocument) -> Bool? {
        (try? document.value(for: key)).flatMap { $0 }?.bool
    }

    private func hasLegacyFeel(_ document: FrontmatterDocument) -> Bool {
        [mapping.legacyFields.needEnergy, mapping.legacyFields.pleasant].contains { (try? document.value(for: $0)).flatMap({ $0 }) != nil }
    }

    /// The app's item settings go into their JSON property; everything else is a key of its own.
    private func set(_ key: String, _ value: YAMLValue?, in document: inout FrontmatterDocument) {
        if settings.keys.contains(key) {
            settings.set(key, to: value, in: &document)
        } else if let value {
            document.set(key, to: value)
        } else {
            document.remove(key)
        }
    }

    /// The items of a list key as they are in the file (a single scalar counts as one item).
    private func listItems(_ key: String, in document: FrontmatterDocument) -> [YAMLValue] {
        guard let value = (try? document.value(for: key)).flatMap({ $0 }) else { return [] }
        if case .null = value { return [] }
        return value.list ?? [value]
    }

    /// Adds or removes one day; other entries (even ones the app can't read) stay as they are, and
    /// a list that already has the right state is not rewritten.
    private func setInstance(_ day: LocalDate, included: Bool, key: String, keepEmpty: Bool, in document: inout FrontmatterDocument) {
        let items = listItems(key, in: document)
        let isDay: (YAMLValue) -> Bool = { FieldValues.firstScalar($0).flatMap(LocalDate.init(isoString:)) == day }
        let matches = items.filter(isDay).count
        guard included ? matches != 1 : matches > 0 else { return }
        var updated = items.filter { !isDay($0) }
        if included { updated.append(.scalar(day.isoString, quoted: false)) }
        if updated.isEmpty, !keepEmpty {
            document.remove(key)
        } else {
            document.set(key, to: .list(updated))
        }
    }

    private func linkName(_ entry: YAMLValue) -> String? {
        FieldValues.firstScalar(entry.value(for: "uid") ?? entry).flatMap(WikiLink.noteName(from:))
    }

    /// The TaskNotes way: `{uid: "[[Name]]", reltype: FINISHTOSTART}`.
    private func newLink(to name: String) -> YAMLValue {
        .map([
            YAMLMapEntry(key: "uid", value: .scalar(WikiLink.make(name), quoted: true)),
            YAMLMapEntry(key: "reltype", value: .scalar(mapping.dependencyRelType, quoted: false)),
        ])
    }

    /// Keeps `reltype`, `gap` and anything else of an object entry; a plain-string entry is rewritten
    /// as a TaskNotes object (links are always written as objects).
    private func relink(_ entry: YAMLValue, to name: String) -> YAMLValue {
        guard case .map(let fields) = entry else { return newLink(to: name) }
        return .map(fields.map { $0.key == "uid" ? YAMLMapEntry(key: "uid", value: .scalar(WikiLink.make(name), quoted: true)) : $0 })
    }

    /// The frontmatter of a brand-new task note, in TaskNotes field order; the body is empty.
    func newNote(tag: String, status: TaskStatus, now: Date) -> String {
        let keys = mapping.fields
        let stamp = YAMLValue.scalar(ISO8601.formatWithMilliseconds(now, timeZone: timeZone), quoted: false)
        let entries: [(String, YAMLValue)] = [
            (keys.tags, .list([.string(tag)])),
            (keys.status, .string(mapping.raw(status))),
            (keys.priority, .string(mapping.priorities.normal)),
            (keys.dateCreated, stamp),
            (keys.dateModified, stamp),
        ]
        let lines = entries.flatMap { YAMLSerializer.lines(key: $0.0, value: $0.1) }
        return (["---"] + lines + ["---"]).joined(separator: "\n") + "\n"
    }
}
