import Foundation

/// Done tasks are filed away by the store (TaskNotes: into a folder Obsidian does not index) as soon as they are done,
/// so a new task may take the same name and old ones do not crowd the search. Habits and repeating tasks stay.
enum DoneFiling {
    static func isDue(_ task: TaskItem) -> Bool {
        !task.isHabit && task.status == .done
    }

    static func due(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter(isDue)
    }

    /// The links to a filed task are met; they are removed from the tasks that wait for it.
    static func unlinking(_ name: String, from tasks: [TaskItem]) -> [TaskItem] {
        NameReferences.waiting(for: name, in: tasks)
    }
}
