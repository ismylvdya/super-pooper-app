import Foundation

/// The user's own lists: third-level headings of the Lists section, each a list (`TaskStatus.custom`).
extension TaskDocument {
    /// The titles of the user's own lists, in the file's order, empty ones too.
    var listTitles: [String] {
        sections.filter { $0.kind == .lists }.flatMap { $0.groups.compactMap(\.title) }
    }

    /// A new empty list at the end of Lists; nothing when one has that title.
    mutating func addList(_ title: String) {
        guard let index = sections.firstIndex(where: { $0.kind == .lists }) else { return }
        _ = listGroup(title, in: index)
    }

    /// Takes a list's heading out of the file; what still stands under it goes to Someday.
    mutating func removeList(_ title: String) {
        guard let index = sections.firstIndex(where: { $0.kind == .lists }),
              let group = sections[index].groups.firstIndex(where: { $0.title == title }) else { return }
        let left = sections[index].groups.remove(at: group).entries
        for entry in left { insert(entry, into: .someday) }
    }

    /// The group of a list in the Lists section at `index`, made at the end when there is none.
    mutating func listGroup(_ title: String, in index: Int) -> Int {
        if let found = sections[index].groups.firstIndex(where: { $0.title == title }) { return found }
        sections[index].groups.append(Group(title: title))
        return sections[index].groups.count - 1
    }
}
