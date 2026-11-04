import SwiftUI

/// The Timezone widget's own page.
struct ClockSettingsScreen: View {
    var body: some View {
        PageScaffold(title: L10n.string("settings.clock.summary")) {
            ClockSettingsSection()
        }
    }
}
