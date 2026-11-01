import Foundation

/// A TaskNotes item is named by its file: Obsidian-safe note names — not empty, no spaces around, not hidden, none of
/// the characters a file name or a link cannot hold, not too long (`field-mapping.json` → `obsidian.noteNames`).
struct ObsidianNoteNames: Sendable {
    let rules: ObsidianConventions.NoteNames

    func isValid(_ name: String) -> Bool {
        problem(in: name) == nil
    }

    /// The first thing wrong with `name`, nil for a name a note can take.
    func problem(in name: String) -> NoteNameProblem? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        if trimmed != name { return .spacesAround }
        if name.hasPrefix(".") { return .leadingDot }
        let forbidden = CharacterSet(charactersIn: rules.forbiddenCharacters)
        if let character = name.first(where: { $0.unicodeScalars.contains(where: forbidden.contains) }) {
            return .forbidden(character)
        }
        return name.count > rules.maxLength ? .tooLong(limit: rules.maxLength) : nil
    }
}
