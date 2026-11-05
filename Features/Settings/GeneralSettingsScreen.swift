import SwiftUI

/// What the whole app stands on: the day's boundary, the Lists, and where everything comes from.
struct GeneralSettingsScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PageScaffold(title: L10n.string("settings.general")) {
            DaySettingsSection()
            ListsSettingsSection()
            AccentSettingsSection()
            SourcesSettingsSection()
        }
        .task { await model.refreshAccess() }
    }
}
