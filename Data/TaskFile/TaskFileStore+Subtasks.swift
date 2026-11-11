import Foundation

/// A subtask goes with its parent: a line under a parent without a date of its own stands on the parent's day and in its
/// list, wherever the parent moves. A subtask with its own date, time or list is on its own; undated with `🔼` beside a
/// dated parent, it was taken out of the day (Not today) and waits in Next actions.
extension TaskFileStore {
    /// The day the subtasks without a date of the open line `id` stand on: none while it has no date itself.
    func followedDay(of id: String, in document: TaskDocument) -> LocalDate? {
        guard let place = place(of: id, in: document), place.entry.box != .done else { return nil }
        return logicalDay(of: place.entry.following(place.parentEntry))
    }

    /// The tasks standing under the line `id`, all the way down.
    func subtasks(under id: String, snapshot: Snapshot) -> [TaskItem] {
        var owners: Set<String> = [id]
        var found: [TaskItem] = []
        snapshot.document.walk { entry, section, parent, index in
            guard let owner = parent?.id, owners.contains(owner), let own = entry.id, snapshot.habits[own] == nil else { return }
            owners.insert(own)
            found.append(item(entry, in: section, parent: parent, index: index, snapshot: snapshot))
        }
        return found
    }

    /// What a day's turn or a hand in Obsidian leaves: a `🔼` line in its parent's section on its parent's day goes under it,
    /// and a line under a parent stops repeating the parent's day.
    func gatherSubtasks(_ document: inout TaskDocument, habits: Set<String>) {
        var strays: [(id: String, parent: String)] = []
        document.walk { entry, section, parent, _ in
            guard parent == nil, section != .done, section != .trash, entry.box != .done, entry.time == nil,
                  let id = entry.id, !habits.contains(id), let owner = entry.parent, owner != id, !habits.contains(owner),
                  let home = place(of: owner, in: document), home.section == section, home.entry.box != .done,
                  logicalDay(of: entry) == logicalDay(of: home.entry.following(home.parentEntry)) else { return }
            strays.append((id, owner))
        }
        for stray in strays {
            guard var taken = document.remove(where: { $0.id == stray.id }) else { continue }
            taken.entry.parent = nil
            if !document.insert(taken.entry, under: stray.parent) {
                // Its parent stands under it (a loop of parents): it stays a line of its own.
                taken.entry.parent = stray.parent
                document.insert(taken.entry, into: taken.section)
            }
        }
        func settle(_ entries: inout [TaskEntry], under parent: TaskEntry?) {
            for index in entries.indices {
                if let id = entries[index].id, !habits.contains(id), let parent { entries[index].leaveDate(to: logicalDay(of: parent)) }
                let owner = entries[index].following(parent)
                settle(&entries[index].children, under: owner)
            }
        }
        for section in document.sections.indices where document.sections[section].kind.map({ $0 != .done && $0 != .trash }) == true {
            for group in document.sections[section].groups.indices { settle(&document.sections[section].groups[group].entries, under: nil) }
        }
    }
}

extension TaskEntry {
    /// An open line standing on its parent's `day` with no time says nothing of its own: it follows.
    mutating func leaveDate(to day: LocalDate?) {
        if box != .done, time == nil, date != nil, date == day { date = nil }
    }
}
