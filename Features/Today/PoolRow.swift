import SwiftUI

/// A task in a rounded plate — the same look in the pool and on the timeline. In the pool the plate
/// grows with the estimate (a long task takes more room), except a parent: its subtasks hold the time, so it stays
/// one line; the long-press highlight is the plate itself.
struct PoolRow: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    let item: DayItem
    var isToday = true
    var isCompact = false
    var plate: PoolRowContent.PlateKind = .pool(.own)
    let handler: TaskActionHandler
    var dragSource: TaskDragState.Source?

    var body: some View {
        let lines = item.hasSubtasks ? 0 : rules.pool.extraLines(forEstimate: rules.day.estimate(of: item.task))
        PoolRowContent(item: item, isToday: isToday, isCompact: isCompact,
                       titleLineLimit: item.hasSubtasks ? 1 : nil, plate: plate,
                       minimumHeight: CGFloat(lines) * tokens.uiFont(.taskTitle).lineHeight, handler: handler,
                       dragSource: dragSource)
            // A subtask sits under its parent, shifted right.
            .padding(.leading, CGFloat(item.depth) * tokens.space(.subtaskIndent))
    }
}
