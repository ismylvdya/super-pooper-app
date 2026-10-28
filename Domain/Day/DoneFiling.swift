import Foundation

/// Done tasks leave the tasks folder for the done folder (which Obsidian and TaskNotes do not index), so a new task
/// may take the same name and old ones do not crowd the search. A task done today stays until the day is over (it
/// can still be unmarked); habits and repeating tasks never move.
enum DoneFiling {
    static func due(_ tasks: [TaskNote], today: LocalDate) -> [TaskNote] {
        tasks.filter { task in
            !task.isHabit && task.status == .done && (task.completedDate.map { $0 < today } ?? true)
        }
    }

    /// The links to a filed task are met; they are removed from the tasks that wait for it.
    static func unlinking(_ name: String, from tasks: [TaskNote]) -> [TaskNote] {
        tasks.filter { $0.previousTasks.contains { $0.isSameNoteName(as: name) } }
    }
}
