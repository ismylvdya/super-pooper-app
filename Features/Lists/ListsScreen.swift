import SwiftUI

/// The Lists tab: the groups of task lists from `lists.json` (by feel: pleasant, needs energy, quick; all statuses:
/// a list per planning level), each list with the number of tasks in it; the search button finds any task.
struct ListsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons

    var body: some View {
        let rules = model.config.rules.day
        PageScaffold(title: L10n.string("tab.lists"), isNested: false) {
            ForEach(model.config.lists.groups) { group in
                PlateSection(header: LocalizedStringKey(group.title)) {
                    ForEach(group.lists) { list in
                        let count = list.filter.groups(of: model.tasks, query: "", rules: rules).reduce(0) { $0 + $1.tasks.count }
                        NavigationLink(value: Route.list(list.id)) {
                            PlateRow(icon: list.icon, title: LocalizedStringKey(list.title)) { DisclosureAccessory(value: "\(count)") }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("lists.\(list.id)")
                    }
                }
            }
        }
        .refreshable { await model.sync(announce: true) }
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
