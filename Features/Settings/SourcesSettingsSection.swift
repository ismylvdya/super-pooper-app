import SwiftUI

/// Vault folder, anchor calendars, "remember at X" reminder lists and permissions.
struct SourcesSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons
    @Environment(\.tokens) private var tokens
    @Environment(\.openURL) private var openURL
    /// One picker for the two buttons: a view shows only one `fileImporter` of those on it and around it.
    private enum FolderChoice { case vault, taskNotes }
    @State private var isPicking = false
    @State private var choice = FolderChoice.vault
    @State private var isImporting = false
    @State private var imported: Int?

    var body: some View {
        PlateSection(header: "settings.sources", hint: "settings.sources.hint") {
            PlateRow(icon: .vault, title: "settings.vault", info: "info.settings.vault") {
                Button(model.vaultName ?? L10n.string("settings.vault.choose")) { pick(.vault) }
                    .lineLimit(1)
            }
            if model.chosenFolder.isWholeVault {
                Label("settings.vault.wholeVault", systemImage: icons[.problem])
                    .font(tokens.font(.hint))
                    .foregroundStyle(tokens.color(.warning))
            }
            ObsidianLinkRows(place: model.chosenFolder.obsidianPlace)
            PlateRow(icon: .vault, title: "settings.import", info: "info.settings.import") {
                if isImporting {
                    ProgressView()
                } else {
                    Button("settings.import.choose") { pick(.taskNotes) }
                        .accessibilityIdentifier("settings.import")
                }
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
        .fileImporter(isPresented: $isPicking, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            switch choice {
            case .vault: Task { await model.selectVault(url) }
            case .taskNotes: runImport(from: url)
            }
        }
    }

    private func pick(_ folder: FolderChoice) {
        choice = folder
        isPicking = true
    }

    private func runImport(from url: URL) {
        isImporting = true
        imported = nil
        Task {
            imported = await model.importTaskNotes(from: url)
            isImporting = false
        }
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
