import SwiftUI

/// How the pool and the timeline look and stand: their colors, order, what done and past items look like, and how Today
/// lays them out.
struct TaskSettingsScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PageScaffold(title: L10n.string("settings.tasks.summary")) {
            ColorSettingsSection()
            PoolSettingsSection()
            EstimateSettingsSection()
            TimelineSettingsSection()
            AppearanceSettingsSection()
            TodaySettingsSection(surfaces: [.upright, .landscape])
        }
        .task { await model.refreshAccess() }
    }
}
