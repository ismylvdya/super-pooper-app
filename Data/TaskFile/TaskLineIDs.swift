import Foundation

/// How the app tells lines apart. A habit's or repeatable task's id is written in the file; a plain task has none there and
/// goes by its line: its name while open, where names are free of each other, its name, day and place in Done and the trash,
/// where the same name may stand many times. A parent named in `🔼` is written as one word.
enum TaskLineIDs {
    private static let openPrefix = "n:"
    private static let filedPrefix = "d:"
    private static let trashedPrefix = "x:"
    private static let separator = "|"

    static func open(_ name: String) -> String { openPrefix + name }

    /// The parent as a line says it: a habit by its id, a plain task by its name in one word.
    static func written(_ parent: String) -> String {
        guard parent.hasPrefix(openPrefix) else { return parent }
        return String(parent.dropFirst(openPrefix.count)).replacingOccurrences(of: " ", with: "_")
    }

    /// Gives every line of a file just read its id, and its parents theirs.
    static func assign(to document: inout TaskDocument, habits: Set<String>) {
        var renamed: [String: String] = [:]
        var seen: [String: Int] = [:]
        var words: [String: String] = [:]

        func make(_ entry: TaskEntry, in section: TaskSection) -> String {
            let base: String
            switch section {
            case .done: base = filedPrefix + entry.name + separator + (entry.completed?.isoString ?? "")
            case .trash: base = trashedPrefix + entry.name + separator + (entry.deleted?.isoString ?? "")
            default: base = openPrefix + entry.name
            }
            seen[base, default: 0] += 1
            let place = seen[base] ?? 1
            return place == 1 ? base : base + separator + String(place)
        }

        func name(_ entries: inout [TaskEntry], in section: TaskSection) {
            // From the end: a line added on top of Done or the trash leaves the others' ids as they were.
            for index in entries.indices.reversed() {
                if let id = entries[index].id, habits.contains(id) {
                    entries[index].writesID = true
                } else {
                    let new = make(entries[index], in: section)
                    if let old = entries[index].id { renamed[old] = new }
                    entries[index].id = new
                    entries[index].writesID = false
                    if section != .done, section != .trash { words[written(new)] = new }
                }
                name(&entries[index].children, in: section)
            }
        }

        func link(_ entries: inout [TaskEntry]) {
            for index in entries.indices {
                if let parent = entries[index].parent, !habits.contains(parent) {
                    entries[index].parent = renamed[parent] ?? words[parent] ?? parent
                }
                link(&entries[index].children)
            }
        }

        for section in document.sections.indices {
            guard let kind = document.sections[section].kind else { continue }
            for group in document.sections[section].groups.indices.reversed() {
                name(&document.sections[section].groups[group].entries, in: kind)
            }
        }
        for section in document.sections.indices where document.sections[section].kind != nil {
            for group in document.sections[section].groups.indices { link(&document.sections[section].groups[group].entries) }
        }
    }
}

extension TaskDocument {
    /// The id of the newest line with that name in a section: the one just put there on top.
    func newest(named name: String, in kind: TaskSection) -> String? {
        var found: String?
        walk { entry, section, _, _ in if found == nil, section == kind, entry.name == name { found = entry.id } }
        return found
    }
}
