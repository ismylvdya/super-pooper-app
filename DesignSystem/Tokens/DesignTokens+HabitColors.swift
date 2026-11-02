import SwiftUI

extension DesignTokens {
    /// A habit's own color (`habit_color`), or the habit color of the palette.
    func habitColor(_ task: TaskItem) -> Color {
        task.habit.color.flatMap { UIColor(hex: $0) }.map(Color.init(uiColor:)) ?? color(.habit)
    }

    /// A habit's marks: in the habit color; a task that simply repeats has them in its name's color, as a task.
    func habitMarkColor(_ task: TaskItem) -> Color {
        task.habit.repeatable ? habitNameColor(task) : habitColor(task)
    }

    /// The habit symbol before a habit's or a repeatable task's name in search and lists: a habit's in its own color, a
    /// repeatable task's always in the habits' color of the palette, whatever color it has for its name and marks.
    func habitSymbolColor(_ task: TaskItem) -> Color { task.habit.repeatable ? color(.habit) : habitColor(task) }

    /// A habit's name: in its own color when it has one; the settings' habit color is for marks and chips only.
    func habitNameColor(_ task: TaskItem) -> Color {
        task.habit.color.flatMap { UIColor(hex: $0) }.map(Color.init(uiColor:)) ?? color(.primaryText)
    }
}
