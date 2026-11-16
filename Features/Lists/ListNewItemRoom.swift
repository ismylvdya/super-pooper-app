import SwiftUI

extension TaskDragState {
    /// The groups of `list` while the dragged "+" is over it: its room (`gap`) at the spot under the finger, in the group
    /// there.
    func hovering(_ groups: [PoolSectionContent], list: String, gap: DayItem?) -> [PoolSectionContent] {
        guard backlogTarget == list, let order = backlogOrder, let gap else { return groups }
        return PoolArrangement.hovering(groups, order: order, dragged: gap, into: listSection)
    }
}
