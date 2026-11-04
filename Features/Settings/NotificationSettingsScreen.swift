import SwiftUI

/// Notifications and alarms on a page of their own.
struct NotificationSettingsScreen: View {
    var body: some View {
        PageScaffold(title: L10n.string("settings.notifications")) {
            NotificationSettingsSection()
        }
        .onDisappear { AlarmSoundPreview.stop() }
    }
}
