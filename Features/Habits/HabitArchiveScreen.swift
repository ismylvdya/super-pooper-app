import SwiftUI

/// Archived habits: open one, bring it back to the Habits list, or move it to the trash.
struct HabitArchiveScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @State private var pendingAction: PendingAction?

    var body: some View {
        PageScaffold(title: L10n.string("habits.archive.title")) {
            Plate {
                ForEach(model.archivedHabits, id: \.name) { habit in
                    HStack {
                        NavigationLink(value: Route.task(habit.name)) {
                            Text(habit.name).foregroundStyle(tokens.habitColor(habit))
                        }
                        Spacer()
                        Menu {
                            ActionMenuContent(menu: .habitArchiveRow, item: nil) { handler.handle($0, taskName: habit.name) }
                        } label: {
                            Image(systemName: icons[.more]).padding(.horizontal, 4)
                        }
                    }
                    .contextMenu {
                        ActionMenuContent(menu: .habitArchiveRow, item: nil) { handler.handle($0, taskName: habit.name) }
                    }
                }
            }
        }
        .onChange(of: model.archivedHabits.isEmpty) { _, isEmpty in
            if isEmpty { router.popToRoot() }
        }
        .actionConfirmation($pendingAction) { handler.run($0.action, taskName: $0.taskName) }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }
}
