import SwiftUI

/// The dragged "+" over the review: its rows make room at the spot under the finger, in the group of the spot (Morning,
/// Day, Evening: the pool's section of that name), over the right third as the subtask of the row above; held at the
/// top or bottom edge it scrolls the list; let go, it opens the new task's page for that spot of the day's pool.
extension MorningReviewList {
    static let newItemOwner = "review"

    /// The rows, with the room of the "+" while it is over the review.
    func shownRows(_ plan: DayPlan) -> [ReviewGroups.Row] {
        let rows = ReviewGroups.rows(plan.pool)
        guard let drag, drag.source == .newItem, drag.backlogTarget == Self.newItemOwner, let order = drag.backlogOrder,
              let group = drag.listSection.flatMap(ReviewGroups.Group.init(rawValue:)) else { return rows }
        return ReviewGroups.rows(rows, gap: TaskDragState.newItemGap, order: order, in: group)
    }

    /// How far the room of the "+" pushed `id` down: its height (the list's rows touch).
    func liftByGap(of id: String) -> CGFloat {
        guard let order = drag?.backlogOrder, drag?.backlogTarget == Self.newItemOwner, let at = order.firstIndex(of: TaskDragState.newItemGap),
              let spot = order.firstIndex(of: id), spot > at else { return 0 }
        return rowHeights[TaskDragState.newItemGap] ?? CGFloat(rules.layoutEstimates.poolRowHeight)
    }

    private func layout(_ plan: DayPlan) -> PoolDropLayout {
        if let dropLayout { return dropLayout }
        let layout = PoolDropLayout(
            rows: plan.pool.compactMap { item in
                rowMids[item.id].map { PoolDropOrder.Row(id: item.id, midY: Double($0), section: ReviewGroups.Group(item.task.habit.timeOfDay).rawValue) }
            },
            headers: ReviewGroups.Group.allCases.compactMap { group in
                headerMids[group.rawValue].map { SectionDropOrder.Header(id: group.rawValue, midY: Double($0)) }
            },
            all: ReviewGroups.rows(plan.pool).compactMap { if case .item(let name) = $0 { name } else { nil } }, inSections: true)
        dropLayout = layout
        return layout
    }

    func newItemMoved(to point: CGPoint?, plan: DayPlan) {
        guard let drag, drag.source == .newItem, let point, takesNewItem(), screenFrame.contains(point),
              point.y < screenFrame.maxY - bottomBar else {
            if let drag, drag.backlogTarget == Self.newItemOwner {
                withAnimation(tokens.animation) {
                    drag.backlogTarget = nil
                    drag.backlogOrder = nil
                    drag.listSection = nil
                }
            }
            drag?.clearNewItemLanding(Self.newItemOwner)
            return
        }
        let layout = layout(plan)
        let drop = PoolDropOrder.drop(rows: layout.rows, all: layout.all, headers: layout.headers, inSections: true,
                                      dragged: TaskDragState.newItemGap, at: Double(point.y))
        let section = drop.section ?? ReviewGroups.Group.day.rawValue
        let asSubtask = NewItemNesting.isSubtaskSide(x: Double(point.x), poolMinX: Double(screenFrame.minX), poolWidth: Double(screenFrame.width),
                                                     share: rules.gestures.subtaskShare)
        let spot = NewItemNesting.spot(order: drop.order, gap: TaskDragState.newItemGap, pool: plan.pool, asSubtask: asSubtask)
        if drop.order != drag.backlogOrder || section != drag.listSection || spot != drag.newItemSpot || drag.backlogTarget != Self.newItemOwner {
            withAnimation(tokens.animation) {
                drag.backlogTarget = Self.newItemOwner
                drag.backlogOrder = drop.order
                drag.listSection = section
                drag.newItemSpot = spot
            }
            Haptics.play(.dragStep)
        }
        let day = plan.today
        drag.setNewItemLanding(Self.newItemOwner) {
            Haptics.play(.drop)
            let placement: NewItemPlacement = spot.parent.map { .subtask(of: $0, index: spot.index, day: day) }
                ?? .pool(order: drop.order, section: section, day: day)
            openNewItem(NewItemSeed(kind: .task, placement: placement, estimate: drag.releasedEstimate))
        }
    }
}
