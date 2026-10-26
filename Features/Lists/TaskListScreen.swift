import SwiftUI

/// One list of the Lists tab: the matching tasks by planning level, searchable. A row opens the task page
/// (every property can be changed there); "+" on a task of a later level brings it to this week, "+" in the
/// bar creates a new this-week task.
struct TaskListScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let listID: String
    @State private var query = ""

    var body: some View {
        let list = model.config.lists.list(listID)
        let filter = list?.filter ?? TaskListFilter()
        let groups = filter.groups(of: model.tasks, query: query, rules: model.config.rules.day)
        List {
            ForEach(groups, id: \.status) { group in
                Section {
                    ForEach(group.tasks, id: \.name) { task in row(task) }
                } header: {
                    // A list of one planning level already says it in its title.
                    if filter.statuses.count > 1 { Text(verbatim: StatusText.title(group.status)) }
                }
            }
        }
        .appList()
        .overlay { if groups.isEmpty { Text("lists.empty").foregroundStyle(tokens.color(.secondaryText)) } }
        .searchable(text: $query, prompt: Text("search.prompt.tasks"))
        .navigationTitle(Text(LocalizedStringKey(list?.title ?? "tab.lists")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.open(.newTask) } label: { Image(systemName: icons[.newTask]) }
                    .accessibilityLabel(Text("task.new.title"))
            }
        }
        .refreshable { await model.sync(announce: true) }
    }

    private func row(_ task: TaskNote) -> some View {
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
        .listRowBackground(tokens.color(.plateBackground))
    }
}
