import Foundation

/// Obsidian-safe note names: not empty, no spaces around, not hidden, no path separators or link syntax characters.
enum NoteNameRules {
    static let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|#^[]")
    static let maxLength = 200

    static func isValid(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed == name && !name.hasPrefix(".") && name.count <= maxLength
            && name.rangeOfCharacter(from: forbidden) == nil
    }
}
