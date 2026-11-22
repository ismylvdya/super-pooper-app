import ListEngineChumbulev
import SwiftUI

/// Untimed tasks of the day, under the headers of the day's sections (Morning, Day, Evening and the user's own): a list of
/// the list engine (look "pool"). A tap opens a task, a long press its menu; no swipes. Carried, a row moves within the
/// pool (today) and into another section (another day: only into another section — its pool has no order of its own),
/// over the right part it becomes the subtask of the row above (today), over the left part it leaves its family, off the pool onto the timeline it gets the time
/// under the finger, onto a backlog page it goes to that list (`TasksCarry`). A block dragged from the timeline lands
/// here and loses its time. The habits of a routine stand joined on one plate; a long task's plate is taller. A section's
/// title is edited in place. The tab bar's "+" carried over the pool opens its place; let go, the new task's page opens
/// for that spot. Pulled down, it syncs.
struct PoolBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    @Environment(\.icons) private var icons
    @Environment(\.actions) private var registry
    @Environment(\.chipOrder) private var chipOrder
    @Environment(\.tasksSpace) private var space
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    let plan: DayPlan
    let handler: TaskActionHandler
    /// Space under the block that belongs to the home indicator (the list scrolls under it).
    let bottomInset: CGFloat
    /// The edges of the list that lie under a system bar.
    let barEdges: Edge.Set
    @State private var dropIn = ListDropIn()
    /// Bumped when a move is refused, so the list shows the pool as it is again.
    @State private var revision = 0

    var body: some View {
        ReorderableList(sections: Binding(get: { sections }, set: moved), look: "pool",
                        actions: { engine.menu(.context(of: $0.task), for: $0, isToday: plan.isToday, poolDay: plan.today) },
                        onRename: { model.renameSection($0, to: $1, on: plan.today) }, traits: traits, onNest: nested,
                        dropIn: dropIn, onDropIn: newItemDropped, space: space, name: TasksCarry.pool, features: features,
                        onTap: { handler.run(registry.definition(.open), taskName: $0.id) },
                        onRefresh: { await model.sync(announce: true) }, onSystemDrop: systemDropped,
                        footer: isLaterDay && !plan.pool.isEmpty ? AnyView(hint("pool.laterDay")) : nil) { row($0) }
            .id(revision)
            .engineNewItem(dropIn, owner: Self.newItemOwner) {
                router.takesNewItemOnTasks
            }
            .onChange(of: drag?.newItemPoint) { _, point in
                if point != nil { drag?.turnAfterDwell(.block(.pool), seconds: rules.gestures.newItemTurnDwellSeconds) }
            }
            .overlay(alignment: .top) {
                if plan.pool.isEmpty { hint(isLaterDay ? "pool.laterDay" : "pool.empty") }
            }
            .frame(idealWidth: tokens.size(.poolWidth))
    }

    private static let newItemOwner = "poolDrop"

    /// A day after today: its pool fills up only with its turn.
    private var isLaterDay: Bool { plan.today > model.context().today }

    /// No swipes in the pool; today's rows nest; another day's pool has no headers to rename.
    private var features: ListFeatures {
        var features: ListFeatures = [.carry, .menu, .haptics, .autoscroll, .dim, .treeLines, .dropIn, .crossList, .crossSection,
                                      .renameSections, .scrollIndicator, .wrapTitles]
        if plan.isToday { features.insert(.nesting) }
        return features
    }

    private var sections: [ListSection<DayItem>] {
        plan.sections.map { section in
            ListSection(id: section.id, title: section.isCustom ? section.title : (section.hasHeader ? L10n.string(section.title) : ""),
                        items: section.items)
        }
    }

    /// Today: the pool's new order, and a row in another section takes it. Another day: only another section.
    private func moved(_ new: [ListSection<DayItem>]) {
        let order = new.flatMap(\.items).map(\.id)
        let was = Dictionary(plan.sections.flatMap { section in section.items.map { ($0.id, section.id) } }, uniquingKeysWith: { first, _ in first })
        let regrouped = new.flatMap { section in section.items.filter { was[$0.id] != section.id }.map { ($0.id, section.id) } }
        for (name, section) in regrouped { model.moveTask(name, toSection: section, poolOrder: order, on: plan.today) }
        if plan.isToday, regrouped.isEmpty {
            Task { await model.setPoolOrder(order) }
        } else if !plan.isToday, regrouped.isEmpty {
            revision += 1
        }
    }

    /// Carried into a family (today), or out of one to the top level where it was let go.
    private func nested(_ name: String, _ nest: ListNest<String>) {
        Task {
            if let parent = nest.parent {
                await model.nest(name, under: parent, index: nest.index)
            } else {
                await model.unnest(name, order: nest.rows)
            }
        }
    }

    private var traits: ListTraits<DayItem> {
        var traits = ListTraits<DayItem>()
        traits.depth = \.depth
        // A high-priority task's soft red over its plate.
        traits.fill = { [tokens] in tokens.plateTint(for: $0.task).map(ThemeColor.init) }
        // The habits of a routine (wormed) share one plate.
        traits.joined = { $0.isHabit && $0.task.habit.timeOfDay != nil }
        // A long task's plate is taller by its estimate; a parent's is not: its subtasks hold the time.
        traits.height = { [rules, tokens] item in
            let lines = item.hasSubtasks ? 0 : rules.pool.extraLines(forEstimate: rules.day.estimate(of: item.task))
            return lines == 0 ? nil : ListTheme.app.rows.minHeight + CGFloat(lines) * tokens.uiFont(.taskTitle).lineHeight
        }
        traits.canNest = { [model, plan] child, parent in plan.isToday && model.canNest(child.id, order: [parent.id, child.id]) }
        return traits
    }

    /// The name with its chips, the started icon before it, the parent over it.
    private func row(_ item: DayItem) -> ListRowContent {
        let started = item.task.isStarted && !item.isDone
        return ListRowContent(title: item.task.name, chips: chips(item),
                              icon: started ? .app(icons[.started]) : nil, iconColor: started ? ThemeColor(tokens.uiColor(.started)) : nil,
                              overline: item.project)
    }

    private func chips(_ item: DayItem) -> [ListChip] {
        RowChip.chips(for: item, order: chipOrder).map { chip in
            ListChip(kind: chip.kind.rawValue, content: .icon(.app(icons[chip.look.icon])),
                     color: ThemeColor(UIColor(tokens.color(of: chip.look, onFill: item.task.isHighPriority))))
        }
    }

    /// The day's order with `name` (or the new item's gap) where it was let go.
    private func order(with name: String, at drop: ListDrop) -> [String] {
        var order = plan.sections.flatMap(\.items).map(\.id).filter { $0 != name }
        let rows = plan.sections.first { $0.id == drop.sectionID }?.items.map(\.id).filter { $0 != name } ?? []
        let at: Int
        if drop.row > 0, rows.indices.contains(drop.row - 1), let before = order.firstIndex(of: rows[drop.row - 1]) {
            at = before + 1
        } else if let first = rows.first, let index = order.firstIndex(of: first) {
            at = index
        } else {
            at = order.count
        }
        order.insert(name, at: at)
        return order
    }

    /// The "+" let go: under the row above (the right part), or at its spot of its section.
    private func newItemDropped(_ drop: ListDrop) {
        let rows = plan.sections.first { $0.id == drop.sectionID }?.items ?? []
        let placement: NewItemPlacement
        if let parent = drop.parentRow, rows.indices.contains(parent) {
            placement = .subtask(of: rows[parent].id, index: drop.indexInParent, day: plan.today)
        } else {
            placement = .pool(order: order(with: TaskDragState.newItemGap, at: drop), section: plan.sections.first?.id == "plain" ? nil : drop.sectionID,
                              day: plan.today)
        }
        router.openNewItem(NewItemSeed(kind: .task, placement: placement, estimate: drag?.releasedEstimate))
    }

    /// A block dragged from the timeline (a system drag) let go here: it loses its time and takes the spot; refused when it
    /// cannot (`canDropInPool`).
    private func systemDropped(_ drop: ListDrop) {
        guard let drag, let item = drag.item else { return }
        let source = drag.source
        drag.end()
        guard case .timeline(let slot) = source else { return }
        guard plan.isToday, model.canDropInPool(item.id, slot: slot) else { return model.refuseDrop(item.id, onto: .pool) }
        Haptics.play(.drop)
        let order = order(with: item.id, at: drop)
        Task { await model.unschedule(item.id, slot: slot, poolOrder: order, on: plan.today) }
        if plan.sections.contains(where: { $0.id == drop.sectionID && $0.hasHeader }) {
            model.moveTask(item.id, toSection: drop.sectionID, poolOrder: order, on: plan.today)
        }
    }

    private func hint(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .secondaryText(.hint)
            .frame(maxWidth: .infinity, minHeight: tokens.size(.poolCounter))
    }

    private var engine: EngineActions {
        EngineActions(model: model, tokens: tokens, registry: registry, icons: icons) { handler.handle($0, taskName: $1) }
    }
}
