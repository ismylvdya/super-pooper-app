import SwiftUI

/// The Settings tab, searchable by the titles of its sections and rows (`SettingsSearchIndex`, the bar's magnifier as on
/// the other tabs). The Task Manager (what all items share, then what only tasks and only habits have), the archive and the trash, the clock, notes. How
/// long the app's signature has left stands at the very end while it is green, at the very top once it turns yellow or red.
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var query = ""
    @State private var isSearching = false

    var body: some View {
        PageScaffold(title: L10n.string("settings.title"), isNested: false) {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                pages
            } else {
                SettingsSearchResults(results: SettingsSearchIndex.results(query)) { query = "" }
            }
        }
        .pageSearch(query: $query, isSearching: $isSearching, prompt: "settings.search.prompt")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                SearchBarButton(isSearching: $isSearching, accessibilityID: "settings.search")
            }
        }
        .task { await model.refreshAccess() }
        .onAppear { model.refreshSigning() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { model.refreshSigning() } }
        .task { await model.refreshTrash() }
    }

    /// The settings as they stand when nothing is searched.
    @ViewBuilder private var pages: some View {
        if let countdown = model.signingCountdown, countdown.level != .ahead { SigningExpiryPlate(countdown: countdown) }
        PlateSection(header: "settings.taskManager") {
            SettingsLink(route: .generalSettings, icon: .general, title: "settings.general")
            SettingsLink(route: .taskSettings, icon: .taskSettings, title: "settings.tasks.summary")
            SettingsLink(route: .notificationSettings, icon: .notifications, title: "settings.notifications")
            SettingsLink(route: .tabBarSettings, icon: .tabBarSettings, title: "settings.tabBar.summary")
            SettingsLink(route: .widgetSettings, icon: .widgets, title: "settings.widgets")
        }
        PlateSection(header: nil) {
            SettingsLink(route: .plainTaskSettings, icon: .plainTaskSettings, title: "settings.plainTasks.summary")
        }
        PlateSection(header: nil) {
            SettingsLink(route: .habitSettings, icon: .habitSettings, title: "settings.habits.summary")
        }
        if model.config.flags.archive || model.hasTrash {
            PlateSection(header: nil) {
                if model.config.flags.archive {
                    SettingsLink(route: .archive, icon: .archive, title: "archive.title", value: "\(model.archivedNotesCount)")
                }
                if model.hasTrash {
                    SettingsLink(route: .trash, icon: .trash, title: "trash.title", value: model.trashCount.map(String.init))
                }
            }
        }
        if !model.conflictedNotes.isEmpty {
            PlateSection(header: nil) {
                SettingsLink(route: .conflicts, icon: .problem, title: "conflicts.title", value: "\(model.conflictedNotes.count)")
            }
        }
        PlateSection(header: "settings.clock") {
            SettingsLink(route: .clockSettings, icon: .clockSettings, title: "settings.clock.summary")
        }
        PlateSection(header: "settings.notes") {
            PlateRow(icon: .title, title: "settings.notes.soon") {}
        }
        #if DEBUG
        DebugSettingsSection()
        #endif
        if let countdown = model.signingCountdown, countdown.level == .ahead { SigningExpiryPlate(countdown: countdown) }
        SettingsFooter()
    }
}
