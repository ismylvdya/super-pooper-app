import SwiftUI

/// The widgets' layout and colors.
struct WidgetSettingsScreen: View {
    var body: some View {
        PageScaffold(title: L10n.string("settings.widgets")) {
            TodaySettingsSection(surfaces: [.widget])
            WidgetColorsSection()
        }
    }
}
