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

    /// `obsidian://open?vault=…&file=…` for a note at `relativePath` from the chosen folder. For the TaskNotes
    /// folder the vault is the folder's parent (or the name from settings) and the path gets the folder's
    /// name (or the prefix from settings) in front.
    static func obsidianURL(relativePath: String, root: URL, isWholeVault: Bool, vaultName: String,
                            pathPrefix: String, noteExtension: String) -> URL? {
        let file = relativePath.hasSuffix(".\(noteExtension)") ? String(relativePath.dropLast(noteExtension.count + 1)) : relativePath
        let vault = isWholeVault ? root.lastPathComponent : (vaultName.isEmpty ? root.deletingLastPathComponent().lastPathComponent : vaultName)
        let prefix = isWholeVault ? "" : (pathPrefix.isEmpty ? root.lastPathComponent : pathPrefix)
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
