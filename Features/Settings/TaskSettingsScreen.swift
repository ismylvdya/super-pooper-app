import SwiftUI

/// What tasks, habits and repeatable tasks share, from what is changed most to what is set once: the day, how Today is laid
/// out, timeline, Lists, colors, widgets, notifications, and at the end where everything comes from.
struct TaskSettingsScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PageScaffold(title: L10n.string("settings.tasks.summary")) {
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
