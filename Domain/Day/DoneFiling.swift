import Foundation

/// Done tasks are filed away by the store (into the Done section) as soon as they are done,
/// so a new task may take the same name and old ones do not crowd the search. Habits and repeating tasks stay.
enum DoneFiling {
    static func isDue(_ task: TaskItem) -> Bool {
        !task.isHabit && task.status == .done
    }

    static func due(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter(isDue)
    }
}
