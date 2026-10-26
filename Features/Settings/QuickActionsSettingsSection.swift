import SwiftUI

/// The Home Screen quick actions: the shortcut 📥 New in inbox runs.
struct QuickActionsSettingsSection: View {
    @Environment(AppModel.self) private var model
    @State private var shortcut = ""

    var body: some View {
        PlateSection(header: "settings.quickActions", info: "info.settings.quickActions") {
            PlateRow(icon: .inboxShortcut, title: "settings.inboxShortcut", info: "info.settings.inboxShortcut") {
                TrailingSpaceTextField(placeholder: "settings.inboxShortcut.placeholder", text: $shortcut)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: shortcut) { _, value in model.updateSettings { $0.quickActions.inboxShortcut = value } }
                    .accessibilityIdentifier("settings.inboxShortcut")
            }
        }
        .onAppear { shortcut = model.settings.quickActions.inboxShortcut }
    }
}
