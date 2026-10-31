import SwiftUI

/// Vault folder, anchor calendars, "remember at X" reminder lists and permissions.
struct SourcesSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons
    @Environment(\.tokens) private var tokens
    @Environment(\.openURL) private var openURL
    @State private var isPickingVault = false

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

/// Where "Open in Obsidian" points: the vault name and the TaskNotes folder's path inside it. A folder in
/// Obsidian's iCloud folder tells both by its path, so the rows are only there for a folder elsewhere (or
/// when one was filled in before). Empty fields use the chosen folder's parent and the folder's own name.
private struct ObsidianLinkRows: View {
    @Environment(AppModel.self) private var model
    let place: ObsidianPlace?

    var body: some View {
        let vault = model.settings.vault
        if place == nil || !vault.obsidianVault.isEmpty || !vault.obsidianPathPrefix.isEmpty {
            PlateRow(icon: .obsidian, title: "settings.obsidian.vault", info: "info.settings.obsidian.vault") {
                TrailingSpaceTextField(placeholder: "settings.obsidian.auto", text: binding(\.obsidianVault))
            }
            PlateRow(icon: nil, title: "settings.obsidian.prefix", indent: true) {
                TrailingSpaceTextField(placeholder: "settings.obsidian.auto", text: binding(\.obsidianPathPrefix))
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AppSettings.Vault, String>) -> Binding<String> {
        Binding(get: { model.settings.vault[keyPath: keyPath] },
                set: { value in model.updateSettings { $0.vault[keyPath: keyPath] = value } })
    }
}
