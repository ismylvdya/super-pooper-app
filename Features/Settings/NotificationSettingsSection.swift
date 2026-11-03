import SwiftUI

struct NotificationSettingsSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PlateSection(header: "settings.notifications", hint: "settings.notifications.hint") {
            PlateRow(icon: .notifications, title: "settings.notifications.enabled", info: "info.settings.notifications") {
                Toggle("settings.notifications.enabled", isOn: Binding(
                    get: { model.settings.notifications.enabled },
                    set: { value in model.updateSettings { $0.notifications.enabled = value } }
                ))
                .labelsHidden()
                .disabled(!model.config.flags.notifications)
            }
            PlateRow(icon: .signing, title: "settings.notifications.signing", info: "info.settings.notifications.signing") {}
            TextField("notification.signing.placeholder", text: Binding(
                get: { model.settings.notifications.signingMessage },
                set: { value in model.updateSettings { $0.notifications.signingMessage = value } }
            ), axis: .vertical)
            .accessibilityIdentifier("settings.notifications.signingMessage")
        }
    }
}
