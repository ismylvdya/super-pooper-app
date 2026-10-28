import SwiftUI

/// Archived tasks and habits in one list. A task goes back to This week / Half year, a habit back to the
/// Habits list; either can go to the trash. When the list empties, the page closes.
struct ArchiveScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.tokens) private var tokens
    @State private var pendingAction: PendingAction?
    @State private var query = ""
    @State private var isSearching = false

    var body: some View {
        PageScaffold(title: L10n.string("archive.title")) {
            let tasks = model.archivedTasks.filter { SearchMatcher.matches($0.name, query) }
            let habits = model.archivedHabits.filter { SearchMatcher.matches($0.name, query) }
            if !tasks.isEmpty {
                PlateSection(header: "archive.tasks") {
                    ForEach(tasks, id: \.name) { task in row(task, menu: .archiveRow, color: tokens.color(.primaryText)) }
                }
            }
            if !habits.isEmpty {
                PlateSection(header: "archive.habits") {
                    ForEach(habits, id: \.name) { habit in row(habit, menu: .habitArchiveRow, color: tokens.habitNameColor(habit)) }
                }
            }
        }
        .pageSearch(query: $query, isSearching: $isSearching, prompt: "search.prompt.tasks")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { SearchBarButton(isSearching: $isSearching, accessibilityID: "archive.search") } }
        .onChange(of: model.archivedNotesCount == 0) { _, isEmpty in
            if isEmpty { router.popToRoot() }
        }
        .actionConfirmation($pendingAction) { handler.run($0.action, taskName: $0.taskName) }
    }

    private func row(_ note: TaskNote, menu: ActionMenu, color: Color) -> some View {
        HStack {
            NavigationLink(value: Route.task(note.name)) { Text(note.name).foregroundStyle(color) }
            Spacer()
            ActionPopoverButton(menu: menu, accessibilityID: "archive.more.\(note.name)") { handler.handle($0, taskName: note.name) }
        }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }
}
