import Foundation

/// The links that open a TaskNotes note in Obsidian.
enum ObsidianLink {
    /// `obsidian://open?vault=…&file=…` for a note at `relativePath` from the chosen folder. The vault and the
    /// folder's path in it come from settings, else from the folder's place in Obsidian's iCloud folder, else the
    /// chosen folder is taken as a vault's own folder (the vault is its parent) or as the vault itself.
    static func url(relativePath: String, root: URL, folder: ChosenFolder, vaultName: String,
                    pathPrefix: String, noteExtension: String) -> URL? {
        let file = relativePath.hasSuffix(".\(noteExtension)") ? String(relativePath.dropLast(noteExtension.count + 1)) : relativePath
        let guessed = folder.obsidianPlace ?? (folder.isWholeVault
            ? ObsidianPlace(vault: root.lastPathComponent, pathPrefix: "")
            : ObsidianPlace(vault: root.deletingLastPathComponent().lastPathComponent, pathPrefix: root.lastPathComponent))
        let vault = vaultName.isEmpty ? guessed.vault : vaultName
        let prefix = pathPrefix.isEmpty ? guessed.pathPrefix : pathPrefix
        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "vault", value: vault),
                                 URLQueryItem(name: "file", value: prefix.isEmpty ? file : "\(prefix)/\(file)")]
        return components.url
    }
}
