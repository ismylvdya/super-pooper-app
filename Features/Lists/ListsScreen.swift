import SwiftUI

/// The Lists page (Today's top left button): the groups of task lists from `lists.json` (by feel: pleasant, needs energy, quick; all statuses:
/// a list per planning level), each list with the number of tasks in it, and the projects (`ProjectList`); the "…" finds any task. With
/// problems (the badge on Today's Lists button) a Problems row comes first and opens them; then Morning review, a page of
/// its own for coming back to it later in the morning.
struct ListsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons

    var body: some View {
        PageScaffold(title: L10n.string("lists.title"), isNested: false) {
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
            projects
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
        .searchOnTitleHold { router.open(.search(.tasks)) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PageMoreMenu(search: { router.open(.search(.tasks)) }, accessibilityID: "lists.more")
            }
        }
    }

    /// The parents shown as projects (`ProjectList`), each with how many open tasks it holds; a row opens the project's
    /// page, where its tasks are. No group while there are none.
    @ViewBuilder private var projects: some View {
        let projects = model.projects
        if !projects.isEmpty {
            PlateSection(header: "lists.group.projects") {
                ForEach(projects, id: \.name) { project in
                    NavigationLink(value: Route.task(project.name)) {
                        PlateRow(icon: .project, title: Text(verbatim: project.name)) {
                            DisclosureAccessory(value: "\(model.openTaskCount(of: project))")
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("lists.project.\(project.name)")
                }
            }
        }
    }
}
