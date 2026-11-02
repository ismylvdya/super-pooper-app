import SwiftUI

/// Archived tasks and habits in one list. A task goes back to Soon / Half year, a habit back to the
/// Habits list (a swipe to the left: back to Soon, back to habits); either can go to the trash. When the list empties,
/// the page closes.
struct ArchiveScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.tokens) private var tokens
    @State private var pendingAction: PendingAction?
    @State private var query = ""
    @State private var isSearching = false
    @State private var titleHeight: CGFloat = 0
    @State private var frames = ListGroupFrames()

    var body: some View {
        let tasks = model.archivedTasks.filter { SearchMatcher.matches($0.name, query) }
        let habits = model.archivedHabits.filter { SearchMatcher.matches($0.name, query) }
        List {
            LargePageTitle(height: $titleHeight) { Text("archive.title") }
                .listGroupSpacer()
            group(tasks, id: "tasks", header: "archive.tasks", menu: .archiveRow, swipes: .archivedTask) { _ in
                tokens.color(.primaryText)
            }
            group(habits, id: "habits", header: "archive.habits", menu: .habitArchiveRow, swipes: .archivedHabit) {
                tokens.habitNameColor($0)
            }
        }
        .listGroupStyle()
        .listGroupBacking(frames)
        .titleScrollsIntoBar(L10n.string("archive.title"), titleHeight: titleHeight)
        .appList()
        // The title starts where the other pages' titles start, not under the list's own top margin.
        .contentMargins(.top, 0, for: .scrollContent)
        .pageSearch(query: $query, isSearching: $isSearching, prompt: "search.prompt.tasks")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { SearchBarButton(isSearching: $isSearching, accessibilityID: "archive.search") } }
        .onChange(of: model.archivedNotesCount == 0) { _, isEmpty in
            if isEmpty { router.popToRoot() }
        }
        .actionConfirmation($pendingAction) { handler.run($0) }
    }

    @ViewBuilder
    private func group(_ notes: [TaskItem], id: String, header: LocalizedStringKey, menu: ActionMenu, swipes: ActionSwipes,
                       color: @escaping (TaskItem) -> Color) -> some View {
        if !notes.isEmpty {
            ListGroupHeader(title: Text(header))
            ForEach(Array(notes.enumerated()), id: \.element.name) { index, note in
                HStack {
                    NavigationLink(value: Route.task(note.name)) { Text(note.name).foregroundStyle(color(note)) }
                    ActionMenuButton(menu: menu, accessibilityID: "archive.more.\(note.name)") { handler.handle($0, taskName: note.name) }
                        .buttonStyle(.borderless)
                }
                .listGroupRow(group: id, id: note.name, index: index, count: notes.count, frames: frames)
                .actionSwipes(swipes, item: DayItem(listed: note), isToday: false) { handler.handle($0, taskName: note.name) }
            }
        }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }
}
