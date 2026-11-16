import Foundation

/// The subtasks of a habit or a repeatable task are tasks (D-178). They stand under the habit's one open line, which the
/// app writes anew (`mirror`, `carryMissedHabits`) and takes away (Done, a tick in Obsidian, delete): whenever a habit's line
/// goes, its subtasks stay, beside it in Next actions naming it (`🔼`), and come back under its next line.
extension TaskFileStore {
    /// Takes the open line of habit `id` out of the file: its subtasks stay in Next actions, naming the habit.
    @discardableResult
    func removeHabitLine(_ id: String, from document: inout TaskDocument) -> TaskEntry? {
        guard var taken = document.remove(where: { $0.id == id && $0.completed == nil })?.entry else { return nil }
        for var child in taken.children {
            child.parent = id
            document.insert(child, into: .soon)
        }
        taken.children = []
        return taken
    }

    /// The habits' lines of today and their next days (`lines`) take the places the habits' lines have in Next actions — the
    /// pool's order is the order of the lines (D-180) — keeping the subtasks under them; a new one goes on top. A habit
    /// with no line now leaves its subtasks beside, naming it; a line beside naming a habit goes under its line.
    func placeHabitLines(_ lines: [TaskEntry], in document: inout TaskDocument, habits: Set<String>) {
        guard let list = document.sections.firstIndex(where: { $0.kind == .soon }) else { return }
        var new = Dictionary(lines.compactMap { line in line.id.map { ($0, line) } }, uniquingKeysWith: { first, _ in first })
        var strays: [String: [TaskEntry]] = [:]
        for group in document.sections[list].groups.indices {
            var kept: [TaskEntry] = []
            for entry in document.sections[list].groups[group].entries {
                if let id = entry.id, habits.contains(id) {
                    guard var line = new.removeValue(forKey: id) else {
                        strays[id, default: []] += entry.children
                        continue
                    }
                    line.children = entry.children
                    kept.append(line)
                } else if let owner = entry.parent, habits.contains(owner), !(entry.id.map(habits.contains) ?? false) {
                    var child = entry
                    child.parent = nil
                    strays[owner, default: []].append(child)
                } else {
                    kept.append(entry)
                }
            }
            document.sections[list].groups[group].entries = kept
        }
        let fresh = lines.filter { $0.id.map { new[$0] != nil } ?? false }
        document.sections[list].groups[0].entries.insert(contentsOf: fresh, at: 0)
        var none: [TaskEntry] = []
        for (id, children) in strays where !children.isEmpty {
            if document.update(id: id, { $0.children += children }) == false { give([id: children], to: &none, document: &document) }
        }
    }

    /// The subtasks go under their habit's new line; those of a habit with no line stay beside, naming it.
    func give(_ children: [String: [TaskEntry]], to lines: inout [TaskEntry], document: inout TaskDocument) {
        var left = children
        for index in lines.indices {
            guard let id = lines[index].id, let own = left.removeValue(forKey: id) else { continue }
            lines[index].children += own
        }
        for (id, entries) in left.sorted(by: { $0.key < $1.key }) {
            for var entry in entries {
                entry.parent = id
                document.insert(entry, into: .soon)
            }
        }
    }

    /// An older file's subtasks of habits were habits of their own, repeating with the parent: each becomes a task once,
    /// beside its habit's line (or in the archive, archived), its settings file going to the habits' trash. Before that,
    /// a backup of the tasks file.
    func makeSubhabitsTasks(_ snapshot: inout Snapshot, root: URL) {
        let subhabits = snapshot.habits.values.filter { $0.parent != nil }.sorted { $0.name < $1.name }
        guard !subhabits.isEmpty else { return }
        _ = try? backups.backup([fileURL(root: root), doneURL(root: root)].filter(fileSystem.fileExists), reason: "subhabits")
        for file in subhabits {
            let source = habitsFolder(root: root).appendingPathComponent(file.id + ".json")
            guard (try? fileSystem.move(source, to: habitsTrash(root: root).appendingPathComponent(file.id + ".json"))) != nil else { continue }
            snapshot.habits[file.id] = nil
            while removeHabitLine(file.id, from: &snapshot.document) != nil {}
            var entry = TaskEntry(name: file.name)
            entry.id = TaskLineIDs.open(file.name)
            entry.writesID = false
            entry.estimate = file.timeEstimate
            entry.isHigh = file.isHighPriority
            entry.feel = file.feel
            entry.note = Self.lines(of: file.note)
            entry.parent = file.parent
            snapshot.document.insert(entry, into: file.isArchived ? .archive : .soon)
        }
        snapshot.indexNames()
    }
}
