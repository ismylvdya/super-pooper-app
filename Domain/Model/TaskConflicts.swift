import Foundation

/// Which fields an edit writes that were also changed elsewhere since the app read the item (the edit wins, the user
/// is told). List edits are deltas and merge by themselves; only single-value fields can clash.
enum TaskConflicts {
    static func fields(_ edits: [TaskEdit], seen: TaskItem, latest: TaskItem) -> [TaskField] {
        var result: [TaskField] = []
        for edit in edits where !edit.mergesByItself {
            let field = edit.field
            if seen.value(of: field) != latest.value(of: field), !result.contains(field) { result.append(field) }
        }
        return result
    }
}
