import SwiftUI

/// The Lists tab: the groups of task lists from `lists.json` (by feel: pleasant, needs energy, quick; all statuses:
/// a list per planning level), each list with the number of tasks in it; the search button finds any task.
struct ListsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons

    var body: some View {
        PageScaffold(title: L10n.string("tab.lists"), isNested: false) {
            ForEach(model.config.lists.groups) { group in
                PlateSection(header: LocalizedStringKey(group.title)) {
                    ForEach(group.lists) { list in
                        let count = model.listContents(list.filter, query: "").count
                        NavigationLink(value: Route.list(list.id)) {
                            PlateRow(icon: list.icon, title: LocalizedStringKey(list.title)) { DisclosureAccessory(value: "\(count)") }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("lists.\(list.id)")
                    }
                }
            }
        }
        // The Done list counts the filed tasks too.
        .task { await model.loadFiledTasks() }
        .refreshable {
            await model.sync(announce: true)
            await model.loadFiledTasks()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.open(.search(.tasks)) } label: { Image(systemName: icons[.search]) }
                    .tint(tokens.color(.accent))
                    .accessibilityLabel(Text("search.title"))
                    .accessibilityIdentifier("lists.search")
            }
        }
    }
}
