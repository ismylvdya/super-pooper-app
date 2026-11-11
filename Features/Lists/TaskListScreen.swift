import SwiftUI

/// One list of the Lists page: the matching tasks by planning level, searchable from the search button in the bar
/// (as on Today), not by pulling the list down. A row opens the task page
/// (every property can be changed there); "+" on a task of a later level brings it to this week. A list of the user's own
/// (`custom`) has a "…" menu: Complete all and Delete list.
struct TaskListScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    let listID: String
    /// A list of the user's own, by its title, in place of a list of `lists.json`.
    var custom: String?
    @State private var query = ""
    @State private var isConfirmingDelete = false
    @State private var isSearching = false
    @State private var pendingAction: PendingAction?
    @State private var frames = ListGroupFrames()

    var body: some View {
        let list = model.config.lists.list(listID)
        let contents = custom.map { model.customListContents($0, query: query) } ?? model.listContents(listID, query: query)
        List {
            ForEach(contents.groups, id: \.status) { group in
                if contents.namesLevels { ListGroupHeader(title: Text(verbatim: StatusText.title(group.status))) } else { ListGroupGap() }
                ForEach(Array(group.tasks.enumerated()), id: \.element.name) { index, task in
                    row(task, group: StatusText.title(group.status), index: index, count: group.tasks.count)
                }
                // Dragged like every list; while a search filters it the rows cannot move.
                .onMove(perform: query.isEmpty ? { source, destination in
                    Haptics.play(.reorder)
                    var order = group.tasks.map(\.name)
                    order.move(fromOffsets: source, toOffset: destination)
                    Task { await model.reorderTasks(order) }
                } : nil)
            }
            filedGroup(contents.filed)
        }
        .listGroupStyle()
        .listGroupBacking(frames)
        .appList()
        .overlay { if contents.isEmpty { Text("lists.empty").foregroundStyle(tokens.color(.secondaryText)) } }
        .pageSearch(query: $query, isSearching: $isSearching, prompt: "search.prompt.tasks")
        .navigationTitle(custom.map { Text(verbatim: $0) } ?? Text(LocalizedStringKey(list?.title ?? "lists.title")))
        .navigationBarTitleDisplayMode(.inline)
        .searchOnTitleHold { isSearching = true }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                PageMoreMenu(search: { isSearching = true }, accessibilityID: "list.more") {
                    if let custom { CustomListMenuItems(title: custom, isConfirmingDelete: $isConfirmingDelete) }
                }
            }
        }
        .customListDeletion(custom, isPresented: $isConfirmingDelete) { dismiss() }
        .task { await model.openList(listID) }
        .syncsOnPull { await model.openList(listID) }
        .actionConfirmation($pendingAction) { handler.run($0) }
    }

    /// The filed tasks, newest first. Return (the menu, a swipe to the right) brings one back to Soon; the actions go by
    /// the filed task, not its name (a new task may have the same name).
    @ViewBuilder private func filedGroup(_ filed: [TaskItem]) -> some View {
        if !filed.isEmpty {
            ListGroupHeader(title: Text("lists.filed"))
            ForEach(Array(filed.enumerated()), id: \.element.id) { index, task in
                HStack(spacing: tokens.space(.iconTextGap)) {
                    TaggedTaskName(name: task.name)
                    Spacer(minLength: 0)
                    if let day = task.completedDate {
                        Text(DateText.format(day, Date.FormatStyle(date: .abbreviated, time: .omitted), calendar: model.calendar))
                            .secondaryText()
                    }
                }
                .listGroupRow(group: "filed", id: task.name, index: index, count: filed.count, frames: frames) {
                    ActionMenuContent(menu: .filedTask, item: DayItem(listed: task), isToday: false) { handler.handle($0, filed: task) }
                }
                .actionSwipes(.task, item: DayItem(listed: task), isToday: false) { handler.handle($0, filed: task) }
            }
        }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }

    private func row(_ task: TaskItem, group: String, index: Int, count: Int) -> some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            NavigationLink(value: Route.task(task.name)) {
                TaggedTaskName(name: task.name)
            }
            if task.canPromote {
                Button {
                    Haptics.play(.move)
                    Task { await model.moveToThisWeek(task.name) }
                } label: { Image(systemName: icons[.add]) }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("lists.toThisWeek"))
                    .accessibilityIdentifier("lists.toThisWeek.\(task.name)")
            }
        }
        // The pool's menu for the task (Not today has no place outside Today); Done (Return for a done one) to the right,
        // Delete to the left.
        .listGroupRow(group: group, id: task.name, index: index, count: count, frames: frames) {
            ActionMenuContent(menu: .context(of: task), item: DayItem(listed: task), isToday: false) {
                handler.handle($0, taskName: task.name)
            }
        }
        .actionSwipes(.task, item: DayItem(listed: task), isToday: false) { handler.handle($0, taskName: task.name) }
    }
}

