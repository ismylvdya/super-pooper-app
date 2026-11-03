import SwiftUI

/// A backlog page left of the pool (Soon, Half year, Someday): the list's tasks for the day shown, on the pool's plates,
/// with the pool's tap and long-press menu; each can be dragged to another page, into the pool or onto the timeline.
/// A task dragged here takes the list's level, and the rows part where the list will hold it; a row dragged off the page
/// closes up, as in the pool.
struct BacklogPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    let list: BacklogList
    let plan: DayPlan
    let handler: TaskActionHandler
    /// Space under the page that belongs to the home indicator (the list scrolls under it).
    let bottomInset: CGFloat
    /// The edges of the list that lie under a system bar (`edgeFades`).
    let barEdges: Edge.Set
    /// The screen's margins beside the page take a drop too: a drag that turned to the page from the edge of the screen
    /// is let go there.
    let edgeInset: CGFloat

    var body: some View {
        let items = rows
        ScrollView {
            LazyVStack(alignment: .leading, spacing: tokens.space(.poolRowGap)) {
                ForEach(items) { item in
                    PoolRow(item: item, isToday: false, isCompact: true, handler: handler, dragSource: .backlog(list.id))
                        .dropGap(drag?.isBacklogGhost(item.id, on: list.id) == true)
                        .closedUp(drag?.isBacklogGap(item.id, on: list.id) == true, gap: tokens.space(.poolRowGap))
                }
            }
        }
        .contentMargins(.bottom, bottomInset + tokens.space(.scrollEndRoom), for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .edgeFades(bottomExtension: bottomInset, barEdges: barEdges)
        .liftRoom()
        .overlay(alignment: .top) {
            if items.isEmpty {
                Text("lists.empty")
                    .secondaryText(.hint)
                    .frame(maxWidth: .infinity, minHeight: tokens.size(.poolCounter))
            }
        }
        .contentShape(Rectangle())
        .modifier(dropTarget)
        .background {
            Color.clear
                .contentShape(Rectangle())
                .modifier(dropTarget)
                .padding(.horizontal, -edgeInset)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("backlog.\(list.id)")
    }

    private var dropTarget: BacklogDropTarget {
        BacklogDropTarget(drag: drag, list: list.id, animation: tokens.animation, canDrop: { model.canBringFromBacklog($0.id) },
                          onDrop: dropped, onRefused: { model.refuseDrop($0.id, onto: .list(list.title)) })
    }

    /// The list's tasks; while a task from elsewhere is over the page, it too, where the name order puts it.
    private var rows: [DayItem] {
        let tasks = model.backlogTasks(list, plan: plan)
        var items = tasks.map(DayItem.init(listed:))
        if let dragged = drag?.item, drag?.isBacklogGhost(dragged.id, on: list.id) == true,
           !tasks.contains(where: { $0.name.isSameNoteName(as: dragged.id) }) {
            let spot = items.firstIndex { NameOrder.precedes(dragged.id, $0.id) } ?? items.count
            items.insert(DayItem(listed: dragged.task), at: spot)
        }
        return items
    }

    private func dropped(_ item: DayItem, from source: TaskDragState.Source) {
        Haptics.play(.drop)
        Task {
            await model.moveToBacklog(item.id, list: list, shown: plan.today, fromShownDay: !source.isBacklog)
        }
    }
}

private struct BacklogDropTarget: ViewModifier {
    let drag: TaskDragState?
    let list: String
    let animation: Animation
    let canDrop: (DayItem) -> Bool
    let onDrop: (DayItem, TaskDragState.Source) -> Void
    let onRefused: (DayItem) -> Void

    func body(content: Content) -> some View {
        if let drag {
            content.onDrop(of: TaskDragState.types, delegate: BacklogDropDelegate(drag: drag, list: list, animation: animation,
                                                                                canDrop: canDrop, onDrop: onDrop, onRefused: onRefused))
        } else {
            content
        }
    }
}
