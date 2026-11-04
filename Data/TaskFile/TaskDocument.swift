import Foundation

/// The tasks file: second-level headings are the sections, third-level ones the groups inside (the pool's sections in
/// Now), lines with a checkbox the tasks. Whatever else the file holds — a section of the user's own, a line that is no
/// task — stays where it is, word for word.
struct TaskDocument: Equatable, Sendable {
    struct Group: Equatable, Sendable {
        var title: String?
        var entries: [TaskEntry] = []
    }

    struct Section: Equatable, Sendable {
        var kind: TaskSection?
        var title: String
        var groups: [Group] = [Group(title: nil)]
        /// The lines that are not tasks, and all the lines of a section of the user's own.
        var other: [String] = []
    }

    private static let sectionPrefix = "## "
    private static let groupPrefix = "### "

    var prelude: [String] = []
    var sections: [Section] = []

    /// A new file: every section, empty.
    init(format: TaskFileFormat) {
        sections = TaskSection.allCases.map { Section(kind: $0, title: format.title(of: $0)) }
    }

    init(text: String, format: TaskFileFormat) {
        let kinds = Dictionary(TaskSection.allCases.map { (format.title(of: $0), $0) }, uniquingKeysWith: { first, _ in first })
            .merging(format.legacySections) { current, _ in current }
        // Where lines go: the deepest entries open now, by their indents.
        var path: [(indent: Int, keys: [Int])] = []
        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix(Self.sectionPrefix) {
                let title = String(line.dropFirst(Self.sectionPrefix.count)).trimmingCharacters(in: .whitespaces)
                sections.append(Section(kind: kinds[title], title: title))
                path = []
                continue
            }
            guard let last = sections.indices.last else {
                prelude.append(line)
                continue
            }
            guard sections[last].kind != nil else {
                sections[last].other.append(line)
                continue
            }
            if line.hasPrefix(Self.groupPrefix) {
                let title = String(line.dropFirst(Self.groupPrefix.count)).trimmingCharacters(in: .whitespaces)
                sections[last].groups.append(Group(title: title))
                path = []
                continue
            }
            let indent = Self.indent(of: line, format: format)
            let content = String(line.drop(while: \.isWhitespace))
            if let entry = TaskEntry(line: content, format: format) {
                while let top = path.last, top.indent >= indent { path.removeLast() }
                let group = sections[last].groups.count - 1
                Self.append(entry, under: path.last?.keys ?? [], in: &sections[last].groups[group].entries)
                let siblings = Self.entries(at: path.last?.keys ?? [], in: sections[last].groups[group].entries)
                path.append((indent, (path.last?.keys ?? []) + [siblings.count - 1]))
            } else if content.isEmpty {
                if let owner = path.last {
                    let group = sections[last].groups.count - 1
                    Self.update(owner.keys, in: &sections[last].groups[group].entries) { $0.note.append("") }
                }
            } else if let owner = path.last(where: { $0.indent < indent }) {
                let group = sections[last].groups.count - 1
                let depth = format.indent.count
                let text = String(line.dropFirst(min(owner.indent + depth, line.prefix { $0.isWhitespace }.count)))
                Self.update(owner.keys, in: &sections[last].groups[group].entries) { $0.note.append(text) }
            } else {
                sections[last].other.append(line)
            }
        }
        for index in sections.indices {
            sections[index].groups = sections[index].groups.map { group in
                var group = group
                group.entries = group.entries.map(Self.trimmingNotes)
                return group
            }
            while sections[index].other.last?.isEmpty == true { sections[index].other.removeLast() }
            while sections[index].other.first?.isEmpty == true { sections[index].other.removeFirst() }
        }
        while prelude.last?.isEmpty == true { prelude.removeLast() }
        mergeLegacySections(format: format)
        for section in TaskSection.allCases where !sections.contains(where: { $0.kind == section }) {
            sections.append(Section(kind: section, title: format.title(of: section)))
        }
    }

    /// A section under an older title goes by its title now. When the file has both, its lines join the other's, which
    /// stays where it stands.
    private mutating func mergeLegacySections(format: TaskFileFormat) {
        var merged: [Section] = []
        let isCurrent = { (section: Section) in section.kind.map { format.title(of: $0) == section.title } ?? false }
        for section in sections where isCurrent(section) || section.kind == nil || !sections.contains(where: { $0.kind == section.kind && isCurrent($0) }) {
            var section = section
            if let kind = section.kind {
                section.title = format.title(of: kind)
                for older in sections where older.kind == kind && !isCurrent(older) && older.title != section.title {
                    guard isCurrent(sections.first { $0.kind == kind && isCurrent($0) } ?? older) else { continue }
                    section.groups[0].entries += older.groups.flatMap(\.entries)
                    section.other += older.other
                }
            }
            merged.append(section)
        }
        sections = merged
    }

    /// The file: an empty line between sections, none between tasks.
    func text(format: TaskFileFormat) -> String {
        var lines = prelude
        if !prelude.isEmpty { lines.append("") }
        for section in sections {
            lines.append(Self.sectionPrefix + section.title)
            for group in section.groups {
                if let title = group.title { lines.append(Self.groupPrefix + title) }
                for entry in group.entries { Self.write(entry, depth: 0, format: format, to: &lines) }
            }
            lines += section.other
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static func write(_ entry: TaskEntry, depth: Int, format: TaskFileFormat, to lines: inout [String]) {
        let indent = String(repeating: format.indent, count: depth)
        lines.append(indent + entry.line(format: format))
        for line in entry.note { lines.append(line.isEmpty ? "" : indent + format.indent + line) }
        for child in entry.children { write(child, depth: depth + 1, format: format, to: &lines) }
    }

    private static func indent(of line: String, format: TaskFileFormat) -> Int {
        line.prefix { $0.isWhitespace }.reduce(0) { $0 + ($1 == "\t" ? format.indent.count : 1) }
    }

    private static func append(_ entry: TaskEntry, under keys: [Int], in entries: inout [TaskEntry]) {
        guard let key = keys.first else {
            entries.append(entry)
            return
        }
        append(entry, under: Array(keys.dropFirst()), in: &entries[key].children)
    }

    private static func entries(at keys: [Int], in entries: [TaskEntry]) -> [TaskEntry] {
        guard let key = keys.first else { return entries }
        return Self.entries(at: Array(keys.dropFirst()), in: entries[key].children)
    }

    private static func update(_ keys: [Int], in entries: inout [TaskEntry], _ change: (inout TaskEntry) -> Void) {
        guard let key = keys.first else { return }
        if keys.count == 1 { change(&entries[key]) } else { update(Array(keys.dropFirst()), in: &entries[key].children, change) }
    }

    /// An empty line at the end of a text belongs to the file's layout, not to the text.
    private static func trimmingNotes(_ entry: TaskEntry) -> TaskEntry {
        var entry = entry
        while entry.note.last?.isEmpty == true { entry.note.removeLast() }
        entry.children = entry.children.map(trimmingNotes)
        return entry
    }
}

extension TaskDocument {
    /// Every entry of a section with its parent, depth first.
    func walk(_ visit: (TaskEntry, _ section: TaskSection, _ parent: TaskEntry?, _ index: Int) -> Void) {
        func descend(_ entries: [TaskEntry], _ section: TaskSection, _ parent: TaskEntry?) {
            for (index, entry) in entries.enumerated() {
                visit(entry, section, parent, index)
                descend(entry.children, section, entry)
            }
        }
        for section in sections {
            guard let kind = section.kind else { continue }
            for group in section.groups { descend(group.entries, kind, nil) }
        }
    }

    /// The entry with that id.
    func entry(id: String) -> TaskEntry? {
        var found: TaskEntry?
        walk { entry, _, _, _ in if found == nil, entry.id == id { found = entry } }
        return found
    }

    /// The line of the item with that id that is not a day in Done.
    func openLine(of id: String) -> TaskEntry? {
        var found: TaskEntry?
        walk { entry, section, _, _ in if found == nil, entry.id == id, section != .done, entry.completed == nil { found = entry } }
        return found
    }

    /// Takes the first entry `matches` accepts out of the file, with its children, and says where it was.
    mutating func remove(where matches: (TaskEntry) -> Bool) -> (entry: TaskEntry, section: TaskSection)? {
        func take(_ entries: inout [TaskEntry]) -> TaskEntry? {
            if let index = entries.firstIndex(where: matches) { return entries.remove(at: index) }
            for index in entries.indices {
                if let found = take(&entries[index].children) { return found }
            }
            return nil
        }
        for section in sections.indices {
            guard let kind = sections[section].kind else { continue }
            for group in sections[section].groups.indices {
                if let found = take(&sections[section].groups[group].entries) { return (found, kind) }
            }
        }
        return nil
    }

    /// Changes the entry with that id where it stands.
    @discardableResult
    mutating func update(id: String, _ change: (inout TaskEntry) -> Void) -> Bool {
        func apply(_ entries: inout [TaskEntry]) -> Bool {
            for index in entries.indices {
                if entries[index].id == id {
                    change(&entries[index])
                    return true
                }
                if apply(&entries[index].children) { return true }
            }
            return false
        }
        for section in sections.indices {
            for group in sections[section].groups.indices where apply(&sections[section].groups[group].entries) { return true }
        }
        return false
    }

    /// Puts an entry in a section, in its first group: at the top (Done, newest first) or at the end.
    mutating func insert(_ entry: TaskEntry, into section: TaskSection, atTop: Bool = false) {
        guard let index = sections.firstIndex(where: { $0.kind == section }) else { return }
        if atTop {
            sections[index].groups[0].entries.insert(entry, at: 0)
        } else {
            sections[index].groups[0].entries.append(entry)
        }
    }

    /// Puts an entry under the one with the id `parent`; false when there is none.
    mutating func insert(_ entry: TaskEntry, under parent: String, at spot: Int? = nil) -> Bool {
        update(id: parent) { owner in
            let index = min(spot ?? owner.children.count, owner.children.count)
            owner.children.insert(entry, at: index)
        }
    }
}
