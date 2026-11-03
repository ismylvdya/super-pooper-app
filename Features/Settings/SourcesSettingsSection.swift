import SwiftUI

/// Vault folder, anchor calendars, "remember at X" reminder lists and permissions.
struct SourcesSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons
    @Environment(\.tokens) private var tokens
    @Environment(\.openURL) private var openURL
    @State private var isPickingVault = false
    @State private var isPickingTaskNotes = false
    @State private var imported: Int?

    var body: some View {
        PlateSection(header: "settings.sources", hint: "settings.sources.hint") {
            PlateRow(icon: .vault, title: "settings.vault", info: "info.settings.vault") {
                Button(model.vaultName ?? L10n.string("settings.vault.choose")) { isPickingVault = true }
                    .lineLimit(1)
            }
            if model.chosenFolder.isWholeVault {
                Label("settings.vault.wholeVault", systemImage: icons[.problem])
                    .font(tokens.font(.hint))
                    .foregroundStyle(tokens.color(.warning))
            }
            ObsidianLinkRows(place: model.chosenFolder.obsidianPlace)
            PlateRow(icon: .vault, title: "settings.import", info: "info.settings.import") {
                Button("settings.import.choose") { isPickingTaskNotes = true }
            }
            .fileImporter(isPresented: $isPickingTaskNotes, allowedContentTypes: [.folder]) { result in
                guard case .success(let url) = result else { return }
                Task { imported = await model.importTaskNotes(from: url) }
            }
            if let imported {
                Text(L10n.format("settings.import.done", imported)).secondaryText(.hint)
            }
            SourceListRows()
            accessRow(.calendars, "settings.access.calendar", "info.settings.access.calendar", model.access.calendars) {
                await model.requestCalendarAccess()
            }
            accessRow(.reminderLists, "settings.access.reminders", "info.settings.access.reminders", model.access.reminders) {
                await model.requestRemindersAccess()
            }
            accessRow(.notifications, "settings.access.notifications", "info.settings.access.notifications", model.access.notifications) {
                await model.requestNotificationAccess()
            }
        }
        .vaultPicker(isPresented: $isPickingVault)
    }

    private func accessRow(_ icon: Icon, _ title: LocalizedStringKey, _ info: LocalizedStringKey, _ access: SourceAccess,
                           request: @escaping () async -> Void) -> some View {
        PlateRow(icon: icon, title: title, info: info) {
            switch access {
            case .granted:
                Image(systemName: icons[.permissionGranted]).foregroundStyle(tokens.color(.pleasant))
            case .notDetermined:
                Button("settings.access.allow") { Task { await request() } }
            case .denied:
                Button("settings.access.openSettings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        }
    }
}
