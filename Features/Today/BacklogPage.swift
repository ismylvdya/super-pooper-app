import ListEngineChumbulev
import SwiftUI

/// A backlog page left of the pool (Soon, Half year, Someday): the list's tasks for the day shown, a list of the list
/// engine on the pool's plates (look "pool"), with the pool's tap and long-press menu; no swipes. Carried, a row moves
/// within the page, over its right part under the row above, onto another page to that list, into the pool or onto the
/// timeline (`TasksCarry`). The tab bar's "+" carried over the page opens its place (a subtask's over the right part);
/// let go, the new task's page opens for that spot of the list. Pulled down, it syncs.
struct BacklogPage: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.actions) private var registry
    @Environment(\.chipOrder) private var chipOrder
    @Environment(\.tasksSpace) private var space
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    let list: BacklogList
    let plan: DayPlan
    let handler: TaskActionHandler
    /// Space under the page that belongs to the home indicator (the list scrolls under it).
    let bottomInset: CGFloat
    /// The edges of the list that lie under a system bar.
    let barEdges: Edge.Set
    /// The screen's margins beside the page.
    let edgeInset: CGFloat
    @State private var dropIn = ListDropIn()

    var body: some View {
        let rows = rows
        ReorderableList(sections: Binding(get: { [ListSection(id: list.id, title: "", items: rows)] }, set: moved), look: "pool",
                        actions: { engine.menu(.context(of: $0.task), for: $0, isToday: false) }, traits: traits, onNest: nested,
                        dropIn: dropIn, onDropIn: newItemDropped, space: space, name: TasksCarry.backlog(list.id),
                        features: [.carry, .menu, .haptics, .autoscroll, .dim, .treeLines, .dropIn, .crossList, .nesting],
                        onTap: { handler.run(registry.definition(.open), taskName: $0.id) },
                        onRefresh: { await model.sync(announce: true) }, onSystemDrop: systemDropped) { row($0) }
            .engineNewItem(dropIn, owner: "backlog.\(list.id)") { router.takesNewItemOnTasks }
            .overlay(alignment: .top) {
                if rows.isEmpty {
                    Text("lists.empty")
                        .secondaryText(.hint)
                        .frame(maxWidth: .infinity, minHeight: tokens.size(.poolCounter))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("backlog.\(list.id)")
    }

    /// The list's tasks, a subtask under its parent, as in the pool.
    private var rows: [DayItem] {
        SubtaskNesting.nested(model.backlogTasks(list, plan: plan).map(DayItem.init(listed:)))
    }

    private func moved(_ new: [ListSection<DayItem>]) {
        let order = new.flatMap(\.items).map(\.id)
        guard order != rows.map(\.id) else { return }
        Task { await model.reorderTasks(order) }
    }

    private func nested(_ name: String, _ nest: ListNest<String>) {
        guard let parent = nest.parent else { return }
        Task { await model.nest(name, under: parent, index: nest.index) }
    }

    private var traits: ListTraits<DayItem> {
        var traits = ListTraits<DayItem>()
        traits.depth = \.depth
        traits.fill = { [tokens] in tokens.plateTint(for: $0.task).map(ThemeColor.init) }
        traits.canNest = { [model] child, parent in model.canNest(child.id, order: [parent.id, child.id]) }
        return traits
    }

    private func row(_ item: DayItem) -> ListRowContent {
        let started = item.task.isStarted
        return ListRowContent(title: item.task.name, chips: RowChip.chips(for: item, order: chipOrder).map { chip in
            ListChip(kind: chip.kind.rawValue, content: .icon(.app(icons[chip.look.icon])),
                     color: ThemeColor(UIColor(tokens.color(of: chip.look, onFill: item.task.isHighPriority))))
        }, icon: started ? .app(icons[.started]) : nil, iconColor: started ? ThemeColor(tokens.uiColor(.started)) : nil, overline: item.project)
    }

    /// The "+" let go: under the row above (the right part), or at its spot of the list.
    private func newItemDropped(_ drop: ListDrop) {
        let rows = rows.map(\.id)
        let placement: NewItemPlacement
        if let parent = drop.parentRow, rows.indices.contains(parent) {
            placement = .subtask(of: rows[parent], index: drop.indexInParent, day: plan.today)
        } else {
            var order = rows
            order.insert(TaskDragState.newItemGap, at: min(drop.row, order.count))
            placement = .list(level: list.status, order: order)
        }
        router.openNewItem(NewItemSeed(kind: .task, placement: placement, estimate: drag?.releasedEstimate))
    }

    /// A block dragged from the timeline (a system drag) let go here: the task goes to this list.
    private func systemDropped(_ drop: ListDrop) {
        guard let drag, let item = drag.item else { return }
        drag.end()
        guard model.canBringFromBacklog(item.id) else { return model.refuseDrop(item.id, onto: .list(list.title)) }
        Haptics.play(.drop)
        Task { await model.moveToBacklog(item.id, list: list, shown: plan.today, fromShownDay: true) }
    }

    private var engine: EngineActions {
        EngineActions(model: model, tokens: tokens, registry: registry, icons: icons) { handler.handle($0, taskName: $1) }
    }
}
