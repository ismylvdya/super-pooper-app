import SwiftUI

/// How a row marks a high-priority task, by the look chosen in the settings (Settings → Pool → High priority): the
/// priority icon before the name or a soft red plate. Nothing marks it where no look is set (widgets).
struct HighPriorityMark: Equatable {
    let look: AppSettings.HighPriorityLook?
    let isHighPriority: Bool

    init(look: AppSettings.HighPriorityLook?, task: TaskItem) {
        self.look = look
        isHighPriority = task.isHighPriority
    }

    var leadsWithIcon: Bool { isHighPriority && look == .leadingIcon }
    var fillsPlate: Bool { isHighPriority && look == .fill }
}

extension DesignTokens {
    /// The soft red a high-priority task's plate is tinted with; nil when the plate keeps its own color.
    func plateTint(_ mark: HighPriorityMark) -> Color? {
        mark.fillsPlate ? color(.high).opacity(opacity(.highPriorityFill)) : nil
    }
}

private struct HighPriorityLookKey: EnvironmentKey {
    static let defaultValue: AppSettings.HighPriorityLook? = nil
}

extension EnvironmentValues {
    /// How high-priority tasks are marked (from the settings); nil marks nothing.
    var highPriorityLook: AppSettings.HighPriorityLook? {
        get { self[HighPriorityLookKey.self] }
        set { self[HighPriorityLookKey.self] = newValue }
    }
}
