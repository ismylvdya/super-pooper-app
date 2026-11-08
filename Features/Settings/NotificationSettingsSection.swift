import SwiftUI

struct NotificationSettingsSection: View {
    @Environment(AppModel.self) private var model

    /// The offered lengths, with the one set by hand in the settings file among them.
    private var snoozeChoices: [Int] {
        Array(Set(model.config.rules.notifications.snoozeChoices + [model.settings.notifications.snoozeMinutes])).sorted()
    }

    var body: some View {
        PlateSection(header: "settings.notifications", hint: "settings.notifications.hint") {
            PlateRow(icon: .notifications, title: "settings.notifications.enabled", info: "info.settings.notifications") {
                SwitchToggle("settings.notifications.enabled", isOn: Binding(
                    get: { model.settings.notifications.enabled },
                    set: { value in model.updateSettings { $0.notifications.enabled = value } }
                ))
                .labelsHidden()
                .disabled(!model.config.flags.notifications)
            }
            PlateRow(icon: .snooze, title: "settings.notifications.snooze", info: "info.settings.notifications.snooze") {
                Picker("settings.notifications.snooze", selection: Binding(
                    get: { model.settings.notifications.snoozeMinutes },
                    set: { value in model.updateSettings { $0.notifications.snoozeMinutes = value } }
                )) {
                    ForEach(snoozeChoices, id: \.self) { Text(L10n.format("estimate.minutes", $0)).tag($0) }
                }
                .labelsHidden()
                .accessibilityIdentifier("settings.notifications.snooze")
            }
            PlateRow(icon: .alarm, title: "settings.notifications.alarmSound", info: "info.alarm") {
                AlarmSoundMenu(selected: model.settings.notifications.alarmSound, defaultChoice: model.config.defaultSettings.values.notifications.alarmSound,
                               shown: model.alarmSoundTitle(model.settings.notifications.alarmSound)) { value in
                    if let value { model.updateSettings { $0.notifications.alarmSound = value } }
                }
                .accessibilityIdentifier("settings.notifications.alarmSound")
            }
            CustomAlarmSoundRows()
            PlateRow(icon: nil, title: "settings.alarm.snoozeText", info: "info.settings.alarm.look") {
                TextField("alarm.snooze", text: Binding(get: { model.settings.notifications.alarmSnoozeText },
                                                        set: { value in model.updateSettings { $0.notifications.alarmSnoozeText = value } }))
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("settings.alarm.snoozeText")
            }
            PlateRow(icon: nil, title: "settings.alarm.snoozeIcon") { SnoozeIconMenu() }
            PlateRow(icon: nil, title: "settings.alarm.snoozeFill") { ColorField(token: .alarmButton) }
            PlateRow(icon: nil, title: "settings.alarm.snoozeWords") { ColorField(token: .alarmButtonText) }
            PlateRow(icon: .signing, title: "settings.notifications.signing", info: "info.settings.notifications.signing") {}
            TextField("notification.signing.placeholder", text: Binding(
                get: { model.settings.notifications.signingMessage },
                set: { value in model.updateSettings { $0.notifications.signingMessage = value } }
            ), axis: .vertical)
            .accessibilityIdentifier("settings.notifications.signingMessage")
        }
    }
}
