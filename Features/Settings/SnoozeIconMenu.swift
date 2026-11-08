import SwiftUI

/// The symbol before the word on an alarm's Snooze button: the bundled one (`icons.json` → `snooze`) first, then the
/// ones `rules.json` offers (`notifications.snoozeIcons`). The bundled one is stored as empty, so it follows the bundle.
struct SnoozeIconMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons
    @Environment(\.tokens) private var tokens

    var body: some View {
        let bundled = icons[.snooze]
        let picked = model.settings.notifications.alarmSnoozeIcon
        Picker("settings.alarm.snoozeIcon", selection: Binding(
            get: { picked.isEmpty ? bundled : picked },
            set: { symbol in model.updateSettings { $0.notifications.alarmSnoozeIcon = symbol == bundled ? "" : symbol } })) {
            ForEach([bundled] + model.config.rules.notifications.snoozeIcons.filter { $0 != bundled }, id: \.self) { symbol in
                Image(systemName: symbol).tag(symbol)
            }
        }
        .labelsHidden()
        .tint(tokens.color(.secondaryText))
        .accessibilityIdentifier("settings.alarm.snoozeIcon")
    }
}
