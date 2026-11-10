import SwiftUI

/// A setting that is one of a few choices: a row with its title (and its info), and under it the system's segmented
/// control, with a select tap felt on every change. Every such choice in the settings is set this way.
struct SettingChoice<Value: Hashable>: View {
    @Environment(AppModel.self) private var model
    let icon: Icon?
    let title: LocalizedStringKey
    var info: LocalizedStringKey?
    let value: WritableKeyPath<AppSettings, Value>
    let options: [Value]
    let label: (Value) -> LocalizedStringKey
    let accessibilityID: String

    var body: some View {
        PlateRow(icon: icon, title: title, info: info) {}
        Picker(title, selection: Binding(get: { model.settings[keyPath: value] }, set: { choice in
            Haptics.play(.select)
            model.updateSettings { $0[keyPath: value] = choice }
        })) {
            ForEach(options, id: \.self) { option in Text(label(option)).tag(option) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(accessibilityID)
    }
}

extension SettingChoice where Value: RawRepresentable, Value.RawValue == String {
    /// Each choice titled by `prefix` and its raw name (`settings.pool.highPriority.fill`).
    init(icon: Icon?, title: LocalizedStringKey, info: LocalizedStringKey? = nil, value: WritableKeyPath<AppSettings, Value>,
         options: [Value], prefix: String, accessibilityID: String) {
        self.init(icon: icon, title: title, info: info, value: value, options: options,
                  label: { LocalizedStringKey(prefix + $0.rawValue) }, accessibilityID: accessibilityID)
    }
}
