import ListEngineChumbulev
import SwiftUI

/// Archived tasks and habits in one list of the list engine, a section each. Swiped to the right, a task goes back to
/// Soon / Half year, a habit back to the Habits list; to the left, either goes to the trash. A tap opens it. Nothing
/// is carried, there is no menu. When the list empties, the page closes.
struct ArchiveScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.actions) private var registry
    @State private var pendingAction: PendingAction?

    var body: some View {
        ReorderableList(sections: .constant(sections), look: "lists", swipes: swipes, features: [.swipes, .haptics, .scrollIndicator, .wrapTitles],
                        onTap: { router.open(.task($0.id)) }) { item in
            ListRowContent(title: item.task.name, titleColor: item.task.isHabit ? ThemeColor(tokens.habitNameColor(item.task)) : nil)
        }
        .ignoresSafeArea()
        .navigationTitle(Text("archive.title"))
        .navigationBarTitleDisplayMode(.large)
        .searchOnTitleHold { router.open(.search(.archive)) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PageMoreMenu(search: { router.open(.search(.archive)) }, accessibilityID: "archive.more")
            }
        }
        .onChange(of: model.archivedNotesCount == 0) { _, isEmpty in
            if isEmpty { router.popToRoot() }
        }
        .actionConfirmation($pendingAction) { handler.run($0) }
    }

    private var sections: [ListSection<DayItem>] {
        [("tasks", "archive.tasks", model.archivedTasks), ("habits", "archive.habits", model.archivedHabits)]
            .filter { !$0.2.isEmpty }
            .map { ListSection(id: $0.0, title: L10n.string($0.1), items: $0.2.map(DayItem.init(listed:))) }
    }

    private func swipes(_ item: DayItem) -> ListSwipes {
        engine.swipes(item.task.isHabit ? .archivedHabit : .archivedTask, for: item, isToday: false)
    }

    private var engine: EngineActions {
        EngineActions(model: model, tokens: tokens, registry: registry, icons: icons) { handler.handle($0, taskName: $1) }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }
}
