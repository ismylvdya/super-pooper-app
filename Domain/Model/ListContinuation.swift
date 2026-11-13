import Foundation

/// A list in a note's text goes on by itself: Return at the end of a line that starts with a list marker (`markers`,
/// "- " or "• ") starts the next line with the same marker; Return on a line that holds only its marker ends the list,
/// taking the marker away. Only a single new line typed counts: a paste is left as it is.
enum ListContinuation {
    struct Edit: Equatable, Sendable {
        let text: String
        /// Where the cursor goes, as a count of characters from the start.
        let cursor: Int

        /// The cursor as a UTF-16 offset, the way a text view counts.
        var utf16Cursor: Int {
            let index = text.index(text.startIndex, offsetBy: min(cursor, text.count))
            return text.utf16.distance(from: text.utf16.startIndex, to: index.samePosition(in: text.utf16) ?? text.utf16.endIndex)
        }
    }

    /// The edit a keystroke asks for before it lands: `typed` put in place of `range` (UTF-16, as a text view tells it)
    /// of `text`. Nil when the keystroke is left as it is.
    static func edit(in text: String, replacing range: NSRange, with typed: String, markers: [String]) -> Edit? {
        guard typed == "\n", let swapped = Range(range, in: text) else { return nil }
        return edit(from: text, to: text.replacingCharacters(in: swapped, with: typed), markers: markers)
    }

    static func edit(from old: String, to new: String, markers: [String]) -> Edit? {
        let before = Array(old), after = Array(new)
        guard after.count == before.count + 1 else { return nil }
        // Where the one new character went in: the first place the texts differ.
        var spot = before.indices.first { before[$0] != after[$0] } ?? before.count
        guard after[spot] == "\n", Array(after[..<spot]) + Array(after[(spot + 1)...]) == before else { return nil }
        // Next to other new lines any of them could be the new one: it is the first, at the end of the line Return was on.
        while spot > 0, after[spot - 1] == "\n" { spot -= 1 }
        let lineStart = after[..<spot].lastIndex(of: "\n").map { $0 + 1 } ?? 0
        let line = String(after[lineStart..<spot])
        guard let marker = markers.first(where: { line.hasPrefix($0) }) else { return nil }
        if line == marker {
            // An empty item: the list ends there, the line is left empty.
            let text = String(after[..<lineStart]) + String(after[(spot + 1)...])
            return Edit(text: text, cursor: lineStart)
        }
        let text = String(after[...spot]) + marker + String(after[(spot + 1)...])
        return Edit(text: text, cursor: spot + 1 + marker.count)
    }
}
