import SwiftUI

/// The Lists tab: the weekly review and the lists of tasks from `lists.json` (pleasant, needs energy, quick …),
/// each with the number of tasks in it.
struct ListsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    var body: some View {
        let rules = model.config.rules.day
        PageScaffold(title: L10n.string("tab.lists"), isNested: false) {
            Plate {
                ForEach(model.config.lists.lists) { list in
                    let count = list.filter.groups(of: model.tasks, query: "", rules: rules).reduce(0) { $0 + $1.tasks.count }
                    NavigationLink(value: Route.list(list.id)) {
                        PlateRow(icon: list.icon, title: LocalizedStringKey(list.title)) { DisclosureAccessory(value: "\(count)") }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("lists.\(list.id)")
                }
            }
        }
        .refreshable { await model.sync(announce: true) }
    }
}
