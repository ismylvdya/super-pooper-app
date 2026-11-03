import SwiftUI

/// Settings of the tasks side, from what is changed most to what is set once: the day, how Today is laid out, the pool, the
/// timeline, Lists, colors, widgets, notifications, and at the end where everything comes from.
struct TaskSettingsScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PageScaffold(title: L10n.string("settings.tasks")) {
            DaySettingsSection()
            TodaySettingsSection()
            PoolSettingsSection()
            TimelineSettingsSection()
            ListsSettingsSection()
            ColorSettingsSection()
            AppearanceSettingsSection()
            WidgetColorsSection()
            NotificationSettingsSection()
            SourcesSettingsSection()
        }
        .task { await model.refreshAccess() }
    }
}
