import Foundation

/// Paths in the chosen folder: where the tasks are, whether it is a whole vault, links that open a note in Obsidian.
enum VaultPaths {
    /// The app is given the TaskNotes folder itself (or, before, the whole vault). The tasks folder
    /// setting is written from the vault root (`TaskNotes/Tasks`); when the chosen folder is that first
    /// component, the rest is used (`Tasks`).
    static func tasksFolder(_ setting: String, in root: URL, exists: (URL) -> Bool) -> String {
        let parts = setting.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count > 1, !exists(root.appendingPathComponent(setting, isDirectory: true)),
              String(parts[0]).isSameNoteName(as: root.lastPathComponent) else { return setting }
        return parts.dropFirst().joined(separator: "/")
    }

    /// Whether the chosen folder is a whole Obsidian vault (it has `.obsidian`) rather than the TaskNotes folder.
    static func isWholeVault(_ root: URL, exists: (URL) -> Bool) -> Bool {
        exists(root.appendingPathComponent(".obsidian", isDirectory: true))
    }

    /// The vault of the chosen folder and the folder's path in it, read from where the folder is: a folder under
    /// Obsidian's iCloud folder (`…/iCloud~md~obsidian/Documents/<vault>/<path>`). Nil for a folder elsewhere.
    static func obsidianPlace(of root: URL, vaultsFolder: String) -> ObsidianPlace? {
        let parts = root.standardizedFileURL.pathComponents
        let folder = vaultsFolder.split(separator: "/").map(String.init)
        guard !folder.isEmpty, parts.count > folder.count,
              let start = (0..<(parts.count - folder.count)).first(where: { Array(parts[$0..<($0 + folder.count)]) == folder })
        else { return nil }
        let vault = start + folder.count
        return ObsidianPlace(vault: parts[vault], pathPrefix: parts[(vault + 1)...].joined(separator: "/"))
    }

    /// `obsidian://open?vault=…&file=…` for a note at `relativePath` from the chosen folder. The vault and the
    /// folder's path in it come from settings, else from the folder's place in Obsidian's iCloud folder, else the
    /// chosen folder is taken as a vault's own folder (the vault is its parent) or as the vault itself.
    static func obsidianURL(relativePath: String, root: URL, folder: ChosenFolder, vaultName: String,
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

    static func relative(_ url: URL, to root: URL) -> String {
        let rootPath = root.standardizedFileURL.resolvingSymlinksInPath().path
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        guard path.hasPrefix(rootPath) else { return url.lastPathComponent }
        return String(path.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

/// What the chosen folder is: the TaskNotes folder or a whole vault, and where it is in Obsidian when its path says.
struct ChosenFolder: Equatable, Sendable {
    var isWholeVault = false
    var obsidianPlace: ObsidianPlace?
}

/// A vault and a folder's path inside it.
struct ObsidianPlace: Equatable, Sendable {
    let vault: String
    let pathPrefix: String
}
