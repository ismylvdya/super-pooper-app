import ListEngineChumbulev
import SwiftUI

/// The dragged "+" over the review (`engineNewItem`): the list opens its place at the spot under the finger, in the group
/// of the spot (Morning, Day, Evening: the pool's section of that name), over the right part as the subtask of the row
/// above; held at the top or bottom edge it scrolls; let go, it opens the new task's page for that spot of the day's
/// pool.
extension MorningReviewList {
    static let newItemOwner = "review"

    func newItemDropped(_ drop: ListDrop, plan: DayPlan) {
        let day = plan.today
        let placement: NewItemPlacement
        if drop.parentRow != nil, let parent = parent(of: drop, plan: plan) {
            placement = .subtask(of: parent, index: drop.indexInParent, day: day)
        } else {
            placement = .pool(order: order(with: drop, plan: plan), section: drop.sectionID, day: day)
        }
        openNewItem(NewItemSeed(kind: .task, placement: placement, estimate: nil))
    }

    /// The group's rows as the review shows them.
    private func rows(of section: String, plan: DayPlan) -> [DayItem] {
        plan.pool.filter { ReviewGroups.Group($0.task.habit.timeOfDay).rawValue == section }
    }

    private func parent(of drop: ListDrop, plan: DayPlan) -> String? {
        let group = rows(of: drop.sectionID, plan: plan)
        return drop.parentRow.flatMap { group.indices.contains($0) ? group[$0].id : nil }
    }

    /// The day's order with the new item's gap where it landed: after the row before it in its group, or before the
    /// group's first row.
    private func order(with drop: ListDrop, plan: DayPlan) -> [String] {
        var order = ReviewGroups.Group.allCases.flatMap { rows(of: $0.rawValue, plan: plan).map(\.id) }
        let group = rows(of: drop.sectionID, plan: plan)
        let at: Int
        if drop.row > 0, group.indices.contains(drop.row - 1), let before = order.firstIndex(of: group[drop.row - 1].id) {
            at = before + 1
        } else if let first = group.first, let index = order.firstIndex(of: first.id) {
            at = index
        } else {
            at = order.count
        }
        order.insert(TaskDragState.newItemGap, at: at)
        return order
    }
}
