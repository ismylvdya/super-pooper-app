import Foundation

/// Lists that point at notes by name (habit order, routines, Skip today, Not today, the pool order):
/// after a rename they point at the new name.
enum NameReferences {
    static func renaming(_ names: [String], from old: String, to new: String) -> [String] {
        names.map { $0.isSameNoteName(as: old) ? new : $0 }
    }

    /// The tasks that wait for `name`: their previous tasks name it (its Next tasks).
    static func waiting(for name: String, in tasks: [TaskNote]) -> [TaskNote] {
        tasks.filter { $0.previousTasks.containsNoteName(name) }
    }

    /// The tasks that refer to `name`, as a previous task or as their parent: a rename rewrites them.
    static func referring(to name: String, in tasks: [TaskNote]) -> [TaskNote] {
        tasks.filter { ($0.previousTasks + $0.projects).containsNoteName(name) }
    }
}
