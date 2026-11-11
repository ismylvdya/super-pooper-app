import SwiftUI

/// The Lists page (Today's top left button): the groups of task lists from `lists.json` (by feel: pleasant, needs energy, quick; all statuses:
/// a list per planning level), each list with the number of tasks in it; the search button finds any task. With
/// problems (the badge on Today's Lists button) a Problems row comes first and opens them; then Morning review, a page of
/// its own for coming back to it later in the morning.
struct ListsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @State private var isNamingList = false
    @State private var deleting: String?

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
            Plate {
                NavigationLink(value: Route.morningReview) {
                    PlateRow(icon: .morningReview, title: "review.title") { DisclosureAccessory() }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("lists.morningReview")
            }
            customLists
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
        .newListAlert(isPresented: $isNamingList) { title in Task { await model.createList(title) } }
        .customListDeletion(deleting, isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }))
        // The Done list counts the filed tasks too.
        .task { await model.loadFiledTasks() }
        .syncsOnPull { await model.loadFiledTasks() }
        .searchOnTitleHold { router.open(.search(.tasks)) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PageMoreMenu(search: { router.open(.search(.tasks)) }, accessibilityID: "lists.more") {
                    Button { isNamingList = true } label: { Label("lists.new", systemImage: icons[.newList]) }
                        .accessibilityIdentifier("lists.more.newList")
                }
            }
        }
    }

    /// The user's own lists, each with its count and, held, Complete all and Delete list; New List at the end.
    private var customLists: some View {
        PlateSection(header: "lists.group.custom") {
            ForEach(model.customLists, id: \.self) { title in
                NavigationLink(value: Route.customList(title)) {
                    PlateRow(icon: .listCustom, title: Text(verbatim: title)) {
                        DisclosureAccessory(value: "\(model.customListContents(title, query: "").count)")
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    CustomListMenuItems(title: title, isConfirmingDelete: Binding(get: { deleting == title },
                                                                                 set: { deleting = $0 ? title : nil }))
                }
                .accessibilityIdentifier("lists.custom.\(title)")
            }
            Button { isNamingList = true } label: {
                PlateRow(icon: .newList, title: "lists.new")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("lists.new")
        }
    }
}
