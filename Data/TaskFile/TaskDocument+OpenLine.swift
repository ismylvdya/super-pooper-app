import Foundation

extension TaskDocument {
    /// Where a note stands in the file, counted from 0, and its name.
    struct OpenLine: Equatable, Sendable {
        let number: Int
        let name: String
    }

    /// The item's line: a habit's open one, not its days in Done, which have its id too; with no open one, nothing: its days stand in Done's file.
    func openLine(of id: String, format: TaskFileFormat) -> OpenLine? {
        func find(_ entries: [TaskEntry], where isIt: (TaskEntry) -> Bool) -> TaskEntry? {
            for entry in entries {
                if entry.id == id, isIt(entry) { return entry }
                if let child = find(entry.children, where: isIt) { return child }
            }
            return nil
        }
        func found(where isIt: (TaskSection, TaskEntry) -> Bool) -> TaskEntry? {
            for section in sections {
                guard let kind = section.kind else { continue }
                for group in section.groups {
                    if let entry = find(group.entries, where: { isIt(kind, $0) }) { return entry }
                }
            }
            return nil
        }
        guard let entry = found(where: { kind, entry in !(kind == .done && entry.writesID) }) ?? found(where: { _, _ in true }) else { return nil }
        let wanted = entry.line(format: format)
        let lines = tasksText(format: format).components(separatedBy: "\n")
        return lines.firstIndex { $0.trimmingCharacters(in: .whitespaces) == wanted }.map { OpenLine(number: $0, name: entry.name) }
    }
}
