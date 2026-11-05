import Foundation

/// Obsidian's own names the TaskNotes store works with (`field-mapping.json` → `obsidian`): the note files, the folder
/// that makes a vault, where Obsidian keeps its iCloud vaults, the link that opens a note and what a note name may be.
struct ObsidianConventions: Codable, Hashable, Sendable {
    /// `obsidian://open?vault=…&file=…`.
    struct OpenURL: Codable, Hashable, Sendable {
        let scheme: String
        let action: String
        let vaultParameter: String
        let fileParameter: String
        /// `obsidian://superpooper-line?…&line=…&name=…`: the app's own plugin opens the note on that line.
        let lineAction: String
        let lineParameter: String
        let nameParameter: String
    }

    struct NoteNames: Codable, Hashable, Sendable {
        /// Characters a file name or a link to it cannot hold.
        let forbiddenCharacters: String
        let maxLength: Int
    }

    static let file = "obsidian.json"

    static func load(bundle: Bundle = .main) throws -> ObsidianConventions {
        try ConfigLoader(bundle: bundle).load(ObsidianConventions.self, from: file)
    }

    let noteExtension: String
    /// A folder with this one inside is a whole vault.
    let configFolder: String
    /// Where Obsidian keeps its iCloud vaults: a folder under it names its vault and its path in it.
    let vaultsFolder: String
    let openURL: OpenURL
    let noteNames: NoteNames
}
