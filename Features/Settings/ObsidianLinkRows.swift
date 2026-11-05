import SwiftUI

/// Where "Open in Obsidian" points: the vault name and the TaskNotes folder's path inside it. A folder in
/// Obsidian's iCloud folder tells both by its path, so the rows are only there for a folder elsewhere (or
/// when one was filled in before). Empty fields use the chosen folder's parent and the folder's own name.
struct ObsidianLinkRows: View {
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
