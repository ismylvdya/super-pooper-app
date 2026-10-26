import SwiftUI

/// The Home Screen quick actions: the Reminders list 📥 New in inbox opens.
struct QuickActionsSettingsSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PlateSection(header: "settings.quickActions", info: "info.settings.quickActions") {
            PlateRow(icon: .inboxShortcut, title: "settings.inboxList", info: "info.settings.inboxList") {
                Picker("settings.inboxList", selection: Binding(
                    get: { model.settings.quickActions.inboxListID },
                    set: { value in model.updateSettings { $0.quickActions.inboxListID = value } }
                )) {
                    Text("settings.inboxList.none").tag("")
                    ForEach(model.availableReminderLists()) { list in Text(verbatim: list.title).tag(list.id) }
                }
                .labelsHidden()
                .accessibilityIdentifier("settings.inboxList")
            }
        }
    }
}
