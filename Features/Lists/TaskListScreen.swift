import SwiftUI

/// One list of the Lists tab: the matching tasks by planning level, searchable from the search button in the bar
/// (as on Today), not by pulling the list down. A row opens the task page
/// (every property can be changed there); "+" on a task of a later level brings it to this week, "+" in the
/// bar creates a new this-week task.
struct TaskListScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.openURL) private var openURL
    let listID: String
    @State private var query = ""
    @State private var isSearching = false
    @State private var pendingAction: PendingAction?
    @State private var frames = ListGroupFrames()

    var body: some View {
        let list = model.config.lists.list(listID)
        let filter = list?.filter ?? TaskListFilter()
        let groups = filter.groups(of: model.tasks, query: query, rules: model.config.rules.day)
        List {
            ForEach(groups, id: \.status) { group in
                // A list of one planning level already says it in its title.
                if filter.statuses.count > 1 { ListGroupHeader(title: Text(verbatim: StatusText.title(group.status))) } else { ListGroupGap() }
                ForEach(Array(group.tasks.enumerated()), id: \.element.name) { index, task in
                    row(task, group: StatusText.title(group.status), isFirst: index == 0, isLast: index == group.tasks.count - 1)
                }
            }
            if filter.statuses.contains(.done) { filedGroup(query: query) }
        }
        .listGroupStyle()
        .listGroupBacking(frames)
        .appList()
        .overlay { if groups.isEmpty { Text("lists.empty").foregroundStyle(tokens.color(.secondaryText)) } }
        .pageSearch(query: $query, isSearching: $isSearching, prompt: "search.prompt.tasks")
        .navigationTitle(Text(LocalizedStringKey(list?.title ?? "tab.lists")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { router.open(.newTask) } label: { Image(systemName: icons[.newTask]) }
                    .accessibilityLabel(Text("task.new.title"))
                SearchBarButton(isSearching: $isSearching, accessibilityID: "list.search")
            }
        }
        .task { if filter.statuses.contains(.done) { await model.loadFiledTasks() } }
        .refreshable {
            await model.sync(announce: true)
            if filter.statuses.contains(.done) { await model.loadFiledTasks() }
        }
        .actionConfirmation($pendingAction) { handler.run($0.action, taskName: $0.taskName) }
    }

    /// The done folder's tasks, newest first: to look back at, not to change (a new task may have the same name).
    @ViewBuilder private func filedGroup(query: String) -> some View {
        let filed = model.filedTasks.filter { SearchMatcher.matches($0.name, query) }
            .sorted { ($0.completedDate?.isoString ?? "") > ($1.completedDate?.isoString ?? "") }
        if !filed.isEmpty {
            ListGroupHeader(title: Text("lists.filed"))
            ForEach(Array(filed.enumerated()), id: \.element.relativePath) { index, task in
                HStack(spacing: tokens.space(.iconTextGap)) {
                    TaggedTaskName(name: task.name)
                    Spacer(minLength: 0)
                    if let day = task.completedDate {
                        Text(day.startDate(in: model.calendar).formatted(date: .abbreviated, time: .omitted))
                            .font(tokens.font(.caption)).foregroundStyle(tokens.color(.secondaryText))
                    }
                }
                .padding(.horizontal, tokens.space(.plateInner))
                .padding(.vertical, tokens.space(.listRowVertical))
                .listGroupRow(group: "filed", id: task.relativePath, isFirst: index == 0, isLast: index == filed.count - 1,
                              frames: frames, separatorInset: tokens.space(.plateInner))
            }
        }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }

    private func row(_ task: TaskNote, group: String, isFirst: Bool, isLast: Bool) -> some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            NavigationLink(value: Route.task(task.name)) {
                TaggedTaskName(name: task.name)
            }
            if task.status != .thisWeek {
                Button {
                    Haptics.play(.light)
                    Task { await model.moveToThisWeek(task.name) }
                } label: { Image(systemName: icons[.add]) }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("lists.toThisWeek"))
                    .accessibilityIdentifier("lists.toThisWeek.\(task.name)")
            }
        }
        .padding(.horizontal, tokens.space(.plateInner))
        .padding(.vertical, tokens.space(.listRowVertical))
        .listGroupRow(group: group, id: task.name, isFirst: isFirst, isLast: isLast, frames: frames,
                      separatorInset: tokens.space(.plateInner))
        // The pool's menu for the task (Not today has no place outside Today).
        .contextMenu {
            ActionMenuContent(menu: task.isHabit ? .habitContext : .taskContext, item: DayItem(listed: task), isToday: false) {
                handler.handle($0, taskName: task.name)
            }
        }
    }
}

