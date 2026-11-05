import SwiftUI

/// The Lists page (Today's top left button): the groups of task lists from `lists.json` (by feel: pleasant, needs energy, quick; all statuses:
/// a list per planning level), each list with the number of tasks in it; the search button finds any task. With
/// problems (the badge on Today's Lists button) a Problems row comes first and opens them.
struct ListsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens

    var body: some View {
        PageScaffold(title: L10n.string("lists.title"), isNested: true) {
            if let problems = TodayButtons.badgeCount(problemCount: model.problemCount, flagOn: model.config.flags.problemBadge) {
                Plate {
                    Button { router.isProblemsPresented = true } label: {
                        PlateRow(icon: .problem, title: "problems.title", iconTint: tokens.color(.problem)) {
                            DisclosureAccessory(value: "\(problems)")
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("lists.problems")
                }
            }
            ForEach(model.config.lists.groups) { group in
                PlateSection(header: LocalizedStringKey(group.title)) {
                    ForEach(group.lists) { list in
                        NavigationLink(value: Route.list(list.id)) {
                            PlateRow(icon: list.icon, title: LocalizedStringKey(list.title)) {
                                DisclosureAccessory(value: "\(model.listCount(list.id))")
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("lists.\(list.id)")
                    }
                }
            }
        }
        // The Done list counts the filed tasks too.
        .task { await model.loadFiledTasks() }
        .syncsOnPull { await model.loadFiledTasks() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.open(.search(.tasks)) } label: { SearchGlyph() }
                    .tint(tokens.color(.accentToolbar))
                    .accessibilityLabel(Text("search.title"))
                    .accessibilityIdentifier("lists.search")
            }
        }
    }
}
