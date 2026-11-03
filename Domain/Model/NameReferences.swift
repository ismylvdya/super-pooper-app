import Foundation

/// Lists that point at notes by name (habit order, routines, Skip today, Not today, the pool order):
/// after a rename they point at the new name.
enum NameReferences {
    static func renaming(_ names: [String], from old: String, to new: String) -> [String] {
        names.map { $0.isSameNoteName(as: old) ? new : $0 }
    }

    /// The tasks that have `name` as their parent: a rename rewrites them.
    static func referring(to name: String, in tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter { $0.projects.containsNoteName(name) }
    }
}
