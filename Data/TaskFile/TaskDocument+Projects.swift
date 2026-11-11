import Foundation

/// An older file's own lists — `### Title` headings under Lists, read now as Someday's (`legacySections`) — become
/// projects once: a parent line of the title marked as a project (`TaskEntry.showsAsProject`), its lines under it as its
/// subtasks. Only Today's headings are the day's sections; a heading anywhere else is such a list.
extension TaskDocument {
    /// True when a heading was made a project.
    @discardableResult
    mutating func makeHeadingsProjects(isTaken: (String) -> Bool) -> Bool {
        var changed = false
        for index in sections.indices where sections[index].kind.map({ $0 != .now }) == true {
            var made = false
            var loose: [TaskEntry] = []
            for group in sections[index].groups {
                guard let title = group.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
                    loose += group.entries
                    continue
                }
                var parent = TaskEntry(name: UniqueName.free(title, isTaken: isTaken))
                parent.id = TaskLineIDs.open(parent.name)
                parent.writesID = false
                parent.showsAsProject = true
                parent.children = group.entries
                loose.append(parent)
                made = true
            }
            guard made else { continue }
            sections[index].groups = [Group(title: nil, entries: loose)]
            changed = true
        }
        return changed
    }
}
