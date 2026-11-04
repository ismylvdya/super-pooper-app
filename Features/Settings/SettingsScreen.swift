import SwiftUI

/// The Settings tab, searchable by the titles of its sections and rows (`SettingsSearchIndex`, the bar's magnifier as on
/// the other tabs). Each part under its own title: tasks, habits, the Timezone widget, notes, then the archive and the trash. How
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
        PlateSection(header: "settings.tasks") {
            SettingsLink(route: .taskSettings, icon: .taskSettings, title: "settings.tasks.summary")
        }
        PlateSection(header: "settings.habits") {
            SettingsLink(route: .habitSettings, icon: .habitSettings, title: "settings.habits.summary")
        }
        if !model.conflictedNotes.isEmpty {
            PlateSection(header: nil) {
                SettingsLink(route: .conflicts, icon: .problem, title: "conflicts.title", value: "\(model.conflictedNotes.count)")
            }
        }
        PlateSection(header: "settings.clock") {
            SettingsLink(route: .clockSettings, icon: .clockSettings, title: "settings.clock.summary")
        }
        PlateSection(header: "settings.tabBar") {
            SettingsLink(route: .tabBarSettings, icon: .tabBarSettings, title: "settings.tabBar.summary")
        }
        PlateSection(header: "settings.notes") {
            PlateRow(icon: .title, title: "settings.notes.soon") {}
        }
        PlateSection(header: "settings.storage") {
            if model.config.flags.archive {
                SettingsLink(route: .archive, icon: .archive, title: "archive.title", value: "\(model.archivedNotesCount)")
            }
            if model.hasTrash {
                SettingsLink(route: .trash, icon: .trash, title: "trash.title", value: model.trashCount.map(String.init))
            }
        }
        #if DEBUG
        DebugSettingsSection()
        #endif
        if let countdown = model.signingCountdown, countdown.level == .ahead { SigningExpiryPlate(countdown: countdown) }
        SettingsFooter()
    }
}
