import Foundation

/// An older file (format 2) had a section of today, `## Today`, whose groups (`### Morning`, `### Day`, an own one) were
/// the pool's sections. Read now, its open lines are in today's pool (`format.pool.tag`) and each group's title is the
/// tag of its section on the lines under it (the section of the rest has none); the lines join Next actions. That
/// file dated every line of today's pool today each morning, so such a date said "in today's pool", not a deadline: a
/// line with no time loses a date up to the file's day (`format.dayMarkerPrefix`), and the mark says it instead.
extension TaskDocument {
    /// True when the file had such a section.
    mutating func takeTodaySections(format: TaskFileFormat) -> Bool {
        let fileDay = prelude.lazy.compactMap { line -> LocalDate? in
            guard line.hasPrefix(format.dayMarkerPrefix), line.hasSuffix(format.dayMarkerSuffix) else { return nil }
            return LocalDate(isoString: String(line.dropFirst(format.dayMarkerPrefix.count).dropLast(format.dayMarkerSuffix.count)))
        }.first
        var found = false
        for index in sections.indices where format.legacyTodaySections.contains(sections[index].title) {
            found = true
            let entries = sections[index].groups.flatMap { group -> [TaskEntry] in
                let word = group.title.map(PoolSectionTag.tag(ofTitle:)).flatMap { $0 == format.pool.restSection || $0.isEmpty ? nil : $0 }
                return group.entries.map { entry in
                    var entry = Self.inTodayPool(entry, fileDay: fileDay)
                    entry.poolSection = entry.poolSection ?? word
                    return entry
                }
            }
            sections[index].groups = [Group(title: nil, entries: entries)]
        }
        return found
    }

    /// An open line and its open subtasks, in today's pool; a date the morning gave a line with no time goes.
    private static func inTodayPool(_ entry: TaskEntry, fileDay: LocalDate?) -> TaskEntry {
        var entry = entry
        if entry.box != .done, entry.completed == nil {
            entry.inTodayPool = true
            if entry.repeats == nil, entry.time == nil, let date = entry.date, let fileDay, date <= fileDay { entry.date = nil }
        }
        entry.children = entry.children.map { inTodayPool($0, fileDay: fileDay) }
        return entry
    }
}

extension TaskDocument {
    /// Changes every line of the planning levels and the archive that is not put away (Done, the trash), subtasks too.
    mutating func forEachOpenLine(_ change: (inout TaskEntry, TaskSection) -> Void) {
        func apply(_ entries: inout [TaskEntry], _ section: TaskSection) {
            for index in entries.indices {
                change(&entries[index], section)
                apply(&entries[index].children, section)
            }
        }
        for section in sections.indices {
            guard let kind = sections[section].kind, kind != .done, kind != .trash else { continue }
            for group in sections[section].groups.indices { apply(&sections[section].groups[group].entries, kind) }
        }
    }
}
