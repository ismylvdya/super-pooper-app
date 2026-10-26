import SwiftUI

/// Settings of the tasks side: sources, day, Today, timeline, pool, appearance, notifications, archive.
struct TaskSettingsScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PageScaffold(title: L10n.string("settings.tasks")) {
            SourcesSettingsSection()
            DaySettingsSection()
            TodaySettingsSection()
            TimelineSettingsSection()
            PoolSettingsSection()
            AppearanceSettingsSection()
            ColorSettingsSection()
            NotificationSettingsSection()
            QuickActionsSettingsSection()
        }
        .task { await model.refreshAccess() }
    }
}
