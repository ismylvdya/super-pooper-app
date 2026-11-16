import Foundation

/// The swipe to the right in a list: one tab right or left (`SubtaskIndent`, D-182).
extension DayCommands {
    /// One tab right, under the row above it in `rows` (the list as shown).
    func indent(_ name: String, rows: [DayItem]) async {
        guard let task = tasks.task(named: name), let edits = SubtaskIndent.indent(name, rows: rows, tasks: tasks.tasks) else { return }
        await writer.write(task, edits)
    }

    /// One level up; out of its parent altogether, its line goes right after the parent's.
    func outdent(_ name: String) async {
        guard let task = tasks.task(named: name), let out = SubtaskIndent.outdent(name, tasks: tasks.tasks) else { return }
        await writer.write(task, out.edits)
        guard out.edits.first == .parent(nil), let moved = tasks.task(named: name) else { return }
        let lines = tasks.tasks.filter { $0.storeOrder != nil && ($0.status == moved.status || $0.name.isSameNoteName(as: out.parent)) }
        await writer.reorder(SubtaskIndent.order(placing: name, after: out.parent, among: lines))
    }
}
