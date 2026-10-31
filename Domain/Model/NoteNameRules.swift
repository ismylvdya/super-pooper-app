import Foundation

/// Why a name cannot be a note's name.
enum NoteNameProblem: Equatable, Sendable {
    case empty
    case spacesAround
    case leadingDot
    case forbidden(Character)
    case tooLong(limit: Int)
}

/// Obsidian-safe note names: not empty, no spaces around, not hidden, no path separators or link syntax characters.
enum NoteNameRules {
    static let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|#^[]")
    static let maxLength = 200

    static func isValid(_ name: String) -> Bool {
        problem(in: name) == nil
    }

    /// The first thing wrong with `name`, nil for a name a note can take.
    static func problem(in name: String) -> NoteNameProblem? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        if trimmed != name { return .spacesAround }
        if name.hasPrefix(".") { return .leadingDot }
        if let character = name.first(where: { $0.unicodeScalars.contains(where: forbidden.contains) }) {
            return .forbidden(character)
        }
        return name.count > maxLength ? .tooLong(limit: maxLength) : nil
    }
}
