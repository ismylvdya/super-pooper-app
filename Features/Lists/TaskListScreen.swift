import ListEngineChumbulev
import SwiftUI

/// One list of the Lists page, a list of the list engine: its tasks by planning level, a section each, searchable from the
/// bar's "…" or a hold of its title (`SearchPage`). A tap opens a task; a long press its menu (the pool's); a swipe to the
/// right is Done, to the left Delete; carried, a row moves anywhere, over the list's right part it becomes the subtask
/// of the row above, over its left part it leaves its family. The Next actions button (a calendar) on a task of a later level brings it there. The tab
/// bar's "+" carried over the list opens its place there (a subtask's over the right part) and opens the new task's page
/// for that spot. The filed tasks, newest first, stand at the end as they are. Pulled down, it syncs.
struct TaskListScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.actions) private var registry
    @Environment(\.openURL) private var openURL
    @Environment(\.chipOrder) private var chipOrder
    let listID: String
    @State private var pendingAction: PendingAction?
    @State private var dropIn = ListDropIn()

    var body: some View {
        let list = model.config.lists.list(listID)
        let contents = model.listContents(listID, query: "")
        ReorderableList(sections: Binding(get: { sections(contents) }, set: { moved($0) }), look: "lists",
                        actions: menu, traits: traits, swipes: swipes, onNest: nested, dropIn: dropIn,
                        onDropIn: { newItemDropped($0, contents: contents) },
                        features: .all.subtracting([.crossList, .crossSection, .renameSections]), lockedSections: [Self.filed],
                        onTap: { if $0.filed == nil { router.open(.task($0.item.id)) } },
                        onRefresh: {
                            await model.sync(announce: true)
                            await model.openList(listID)
                        }) { row($0) }
            .ignoresSafeArea()
            .engineNewItem(dropIn, owner: "list.\(listID)") { router.path.last == .list(listID) }
            .overlay { if contents.isEmpty { Text("lists.empty").foregroundStyle(tokens.color(.secondaryText)) } }
            .navigationTitle(Text(LocalizedStringKey(list?.title ?? "lists.title")))
            .navigationBarTitleDisplayMode(.inline)
            .searchOnTitleHold { router.open(search) }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    PageMoreMenu(search: { router.open(search) }, accessibilityID: "list.more")
                }
            }
            .task { await model.openList(listID) }
            .actionConfirmation($pendingAction) { handler.run($0) }
    }

    private static let filed = "filed"

    /// The search of this list: its own tasks.
    private var search: Route { .search(.list(listID)) }

    /// The levels, each a section (titled when the list holds more than one), a subtask under its parent; the filed ones
    /// after them.
    private func sections(_ contents: TaskListContents) -> [ListSection<ListedRow>] {
        let shown = Set(contents.groups.flatMap(\.tasks).map(\.name.noteName))
        var sections = contents.groups.map { group in
            ListSection(id: Self.key(group.status), title: contents.namesLevels ? StatusText.title(group.status) : "",
                        items: SubtaskNesting.nested(group.tasks.map(DayItem.init(listed:))).map { item in
                            var item = item
                            item.project = ShownParent.parent(of: item.task, shown: shown)
                            return ListedRow(item: item)
                        })
        }
        if !contents.filed.isEmpty {
            sections.append(ListSection(id: Self.filed, title: L10n.string("lists.filed"),
                                        items: contents.filed.map { ListedRow(item: DayItem(listed: $0), filed: $0) }))
        }
        return sections
    }

    private static func key(_ status: TaskStatus) -> String { String(describing: status) }

    /// A level's rows in their new order.
    private func moved(_ new: [ListSection<ListedRow>]) {
        let old = sections(model.listContents(listID, query: ""))
        for section in new where section.id != Self.filed {
            let order = section.items.map(\.item.id)
            guard old.first(where: { $0.id == section.id })?.items.map(\.item.id) != order else { continue }
            Task { await model.reorderTasks(order) }
        }
    }

    /// Carried into a family (over the right part under the row above), or out of one to the top level where it was let go.
    private func nested(_ id: String, _ nest: ListNest<String>) {
        guard let name = ListedRow.name(of: id) else { return }
        Task {
            if let parent = nest.parent {
                guard let parent = ListedRow.name(of: parent) else { return }
                await model.nest(name, under: parent, index: nest.index)
            } else {
                await model.unnest(name, order: nest.rows.compactMap(ListedRow.name(of:)))
            }
        }
    }

    private var traits: ListTraits<ListedRow> {
        var traits = ListTraits<ListedRow>()
        traits.depth = { $0.filed == nil ? $0.item.depth : 0 }
        // A high-priority task's soft red over its row, as in the pool.
        traits.fill = { [tokens] in tokens.plateTint(for: $0.item.task).map(ThemeColor.init) }
        traits.canNest = { [model] child, parent in model.canNest(child.item.id, order: [parent.item.id, child.item.id]) }
        return traits
    }

    /// The pool's menu for a task (Not today has no place outside Today); a filed one's own.
    private func menu(_ row: ListedRow) -> [ListAction] {
        if let filed = row.filed {
            return EngineActions(model: model, tokens: tokens, registry: registry, icons: icons) { action, _ in handler.handle(action, filed: filed) }
                .menu(.filedTask, for: row.item, isToday: false)
        }
        return engine.menu(.context(of: row.item.task), for: row.item, isToday: false)
    }

    /// To the right Done, to the left Delete; a filed task to the right back to Soon.
    private func swipes(_ row: ListedRow) -> ListSwipes {
        if let filed = row.filed {
            return EngineActions(model: model, tokens: tokens, registry: registry, icons: icons) { action, _ in handler.handle(action, filed: filed) }
                .swipes(.task, for: row.item, isToday: false)
        }
        return engine.swipes(.listTask, for: row.item, isToday: false)
    }

    /// As the pool's row: the name with its chips, the started icon before it, the parent over it when the parent is not in
    /// the list; a task of a later level with the button that brings it to Next actions; a filed one with its day.
    @ViewBuilder private func row(_ row: ListedRow) -> some View {
        let task = row.item.task
        if row.filed != nil {
            ListRowContent(title: task.name, chips: task.completedDate.map { day in
                [ListChip(kind: "day", content: .text(DateText.format(day, Date.FormatStyle(date: .abbreviated, time: .omitted), calendar: model.calendar)),
                          color: ThemeColor(tokens.uiColor(.secondaryText)))]
            } ?? [])
        } else {
            let started = task.isStarted
            HStack(spacing: tokens.space(.iconTextGap)) {
                ListRowContent(title: task.name, chips: chips(row.item),
                               icon: started ? .app(icons[.started]) : nil, iconColor: started ? ThemeColor(tokens.uiColor(.started)) : nil,
                               overline: row.item.project)
                if task.canPromote {
                    Button {
                        Haptics.play(.move)
                        Task { await model.moveToThisWeek(task.name) }
                    } label: { Image(systemName: icons[.listThisWeek]) }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("lists.toThisWeek"))
                        .accessibilityIdentifier("lists.toThisWeek.\(task.name)")
                }
            }
        }
    }

    /// The row's chips, in the pool's order.
    private func chips(_ item: DayItem) -> [ListChip] {
        RowChip.chips(for: item, order: chipOrder).map { chip in
            ListChip(kind: chip.kind.rawValue, content: .icon(.app(icons[chip.look.icon])),
                     color: ThemeColor(UIColor(tokens.color(of: chip.look, onFill: item.task.isHighPriority))))
        }
    }

    /// The "+" let go: under the row above (over the right part), or at its spot of its level.
    private func newItemDropped(_ drop: ListDrop, contents: TaskListContents) {
        let level = contents.groups.first { Self.key($0.status) == drop.sectionID }?.status ?? .thisWeek
        let rows = sections(contents).first { $0.id == drop.sectionID }?.items.map(\.item.id) ?? []
        let placement: NewItemPlacement
        if let parent = drop.parentRow, rows.indices.contains(parent) {
            placement = .subtask(of: rows[parent], index: drop.indexInParent, day: model.context().today)
        } else {
            var order = rows
            order.insert(TaskDragState.newItemGap, at: min(drop.row, order.count))
            placement = .list(level: TaskStatus.open.contains(level) ? level : .thisWeek, order: order)
        }
        router.openNewItem(NewItemSeed(kind: .task, placement: placement, estimate: nil))
    }

    private var engine: EngineActions {
        EngineActions(model: model, tokens: tokens, registry: registry, icons: icons) { handler.handle($0, taskName: $1) }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }
}

/// A row of a Lists page list: a task, or a filed one (a done task may share an open one's name, so its id is its own).
struct ListedRow: Identifiable, Hashable {
    let item: DayItem
    var filed: TaskItem?

    var id: String { filed == nil ? item.id : "filed:" + String(describing: item.task.id) }

    /// The task's name behind a row's id (a filed row has none to nest).
    static func name(of id: String) -> String? {
        id.hasPrefix("filed:") ? nil : id
    }
}

/// A row's frame on the screen, told as it changes.
struct RowTracking: ViewModifier {
    let onChange: (CGRect) -> Void

    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onChange($0) }
    }
}
