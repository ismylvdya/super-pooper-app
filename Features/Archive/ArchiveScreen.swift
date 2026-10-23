import SwiftUI

/// Tasks with status `archived`; each can go back to This week / Half year or to the trash.
/// When the list empties, the app returns to the main screen.
struct ArchiveScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @State private var pendingAction: PendingAction?

    var body: some View {
        PageScaffold(title: L10n.string("archive.title")) {
            Plate {
                ForEach(model.archivedTasks, id: \.name) { task in
                    HStack {
                        NavigationLink(value: Route.task(task.name)) {
                            Text(task.name).foregroundStyle(tokens.color(.primaryText))
                        }
                        Spacer()
                        Menu {
                            ActionMenuContent(menu: .archiveRow, item: nil) { handler.handle($0, taskName: task.name) }
                        } label: {
                            Image(systemName: icons[.more]).padding(.horizontal, 4)
                        }
                    }
                    .contextMenu {
                        ActionMenuContent(menu: .archiveRow, item: nil) { handler.handle($0, taskName: task.name) }
                    }
                }
            }
        }
        .onChange(of: model.archivedTasks.isEmpty) { _, isEmpty in
            if isEmpty { router.popToRoot() }
        }
        .actionConfirmation($pendingAction) { handler.run($0.action, taskName: $0.taskName) }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }
}
