import SwiftUI

/// The Settings tab: while the app's signature runs out soon, how long it has left; two entries (tasks and habits), the
/// trash, the clock, then build version and credits.
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        PageScaffold(title: L10n.string("settings.title"), isNested: false) {
            if let countdown = model.signingCountdown { SigningExpiryPlate(countdown: countdown) }
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
                if model.hasTrash {
                    SettingsLink(route: .trash, icon: .trash, title: "trash.title", value: model.trashCount.map(String.init))
                }
            }
            #if DEBUG
            DebugSettingsSection()
            #endif
            SettingsFooter()
        }
        .task { await model.refreshAccess() }
        .onAppear { model.refreshSigning() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { model.refreshSigning() } }
        .task { await model.refreshTrash() }
    }
}
