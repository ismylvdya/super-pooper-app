import SwiftUI

/// The Settings tab: two entries (tasks and habits), the trash, the clock, then build version and credits.
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PageScaffold(title: L10n.string("settings.title"), isNested: false) {
            PlateSection(header: nil) {
                SettingsLink(route: .taskSettings, icon: .taskSettings, title: "settings.tasks")
                SettingsLink(route: .habitSettings, icon: .habitSettings, title: "settings.habits")
            }
            if !model.conflictedNotes.isEmpty {
                PlateSection(header: nil) {
                    SettingsLink(route: .conflicts, icon: .problem, title: "conflicts.title", value: "\(model.conflictedNotes.count)")
                }
            }
            ClockSettingsSection()
            PlateSection(header: nil) {
                if model.config.flags.archive, model.archivedNotesCount > 0 {
                    SettingsLink(route: .archive, icon: .archive, title: "archive.title", value: "\(model.archivedNotesCount)")
                }
                SettingsLink(route: .trash, icon: .trash, title: "trash.title", value: model.trashCount.map(String.init))
            }
            #if DEBUG
            DebugSettingsSection()
            #endif
            SettingsFooter()
        }
        .task { await model.refreshAccess() }
        .task { await model.refreshTrash() }
    }
}
