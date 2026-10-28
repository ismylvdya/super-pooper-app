import Foundation

/// Done tasks leave the tasks folder for the done folder (which Obsidian and TaskNotes do not index) as soon as they
/// are done, so a new task may take the same name and old ones do not crowd the search. Habits and repeating tasks
/// never move.
enum DoneFiling {
    static func isDue(_ task: TaskNote) -> Bool {
        !task.isHabit && task.status == .done
    }

    static func due(_ tasks: [TaskNote]) -> [TaskNote] {
        tasks.filter(isDue)
    }

    /// The links to a filed task are met; they are removed from the tasks that wait for it.
    static func unlinking(_ name: String, from tasks: [TaskNote]) -> [TaskNote] {
        tasks.filter { $0.previousTasks.contains { $0.isSameNoteName(as: name) } }
    }
}
