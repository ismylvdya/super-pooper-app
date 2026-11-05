import SwiftUI

/// The tab bar's accent color: whether it has one and, if so, which.
struct AccentSettingsSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PlateSection(header: "settings.accent") {
            PlateRow(icon: nil, title: "settings.accent.tabBar") {
                SwitchToggle("settings.accent.tabBar", isOn: Binding(get: { model.settings.accent.tabBar },
                                                                     set: { isOn in model.updateSettings { $0.accent.tabBar = isOn } }))
                    .labelsHidden()
                    .accessibilityIdentifier("settings.accent.tabBar")
            }
            if model.settings.accent.tabBar {
                PlateRow(icon: nil, title: "settings.accent.color", indent: true) {
                    ThemeColorField(token: .tabBarPick)
                }
            }
        }
    }
}
