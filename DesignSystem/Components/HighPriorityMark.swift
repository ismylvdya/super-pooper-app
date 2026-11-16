import SwiftUI

extension DesignTokens {
    /// A high-priority task's plate is tinted soft red everywhere a task stands (pool, timeline, lists, the review,
    /// widgets); nil for any other task, whose plate keeps its own color (D-184).
    func plateTint(for task: TaskItem) -> Color? {
        task.isHighPriority ? color(.high).opacity(opacity(.highPriorityFill)) : nil
    }
}
