import Foundation

/// Renders a frontmatter entry the way Obsidian writes it: two-space block lists, `key: []` for empty lists,
/// and plain scalars unless quoting is needed.
enum YAMLSerializer {
    private static let indent = "  "
    private static let indicators: Set<Unicode.Scalar> = [",", "[", "]", "{", "}", "#", "&", "*", "!", "|", ">", "'", "\"", "%", "@", "`"]
    private static let indicatorsBeforeSpace: Set<Unicode.Scalar> = ["-", "?", ":"]
    private static let namedEscapes: [Unicode.Scalar: String] = ["\"": "\\\"", "\\": "\\\\", "\n": "\\n", "\t": "\\t", "\r": "\\r", "\0": "\\0"]

    /// Lines without line endings.
    static func lines(key: String, value: YAMLValue) -> [String] {
        entryLines(key: key, value: value, indentation: "")
    }

    /// Text with double quotes in it (JSON in a property) goes in single quotes, so it needs no escapes.
    static func scalarText(_ text: String, quoted: Bool) -> String {
        guard quoted || needsQuotes(text) else { return text }
        if text.contains("\""), !text.contains("'"), !text.unicodeScalars.contains(where: isControl) { return "'\(text)'" }
        return doubleQuoted(text)
    }

    /// Whether plain text would be misread or rejected by a YAML parser.
    static func needsQuotes(_ text: String) -> Bool {
        let scalars = Array(text.unicodeScalars)
        guard let first = scalars.first, let last = scalars.last else { return true }
        if first == " " || last == " " || last == ":" || scalars.contains(where: isControl) {
            return true
        }
        if indicators.contains(first) {
            return true
        }
        if indicatorsBeforeSpace.contains(first) && (scalars.count == 1 || scalars[1] == " ") {
            return true
        }
        return text.contains(": ") || text.contains(" #")
    }

    static func doubleQuoted(_ text: String) -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            if let escape = namedEscapes[scalar] {
                result += escape
            } else if isControl(scalar) {
                result += hexEscape(scalar)
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }

    // MARK: - Nodes

    private static func entryLines(key: String, value: YAMLValue, indentation: String) -> [String] {
        let head = indentation + scalarText(key, quoted: false) + ":"
        switch value {
        case .null:
            return [head]
        case .scalar(let text, let quoted):
            return [head + " " + scalarText(text, quoted: quoted)]
        case .list(let items) where items.isEmpty:
            return [head + " []"]
        case .map(let entries) where entries.isEmpty:
            return [head + " {}"]
        case .list, .map:
            return [head] + collectionLines(value, indentation: indentation + indent)
        }
    }

    private static func itemLines(_ item: YAMLValue, indentation: String) -> [String] {
        let dash = indentation + "-"
        switch item {
        case .null:
            return [dash]
        case .scalar(let text, let quoted):
            return [dash + " " + scalarText(text, quoted: quoted)]
        case .list(let items) where items.isEmpty:
            return [dash + " []"]
        case .map(let entries) where entries.isEmpty:
            return [dash + " {}"]
        case .list, .map:
            // A nested collection starts on the dash line: "- k1: v1" / "  k2: v2".
            let nestedIndentation = indentation + indent
            var lines = collectionLines(item, indentation: nestedIndentation)
            if let first = lines.first {
                lines[0] = dash + " " + first.dropFirst(nestedIndentation.count)
            }
            return lines
        }
    }

    private static func collectionLines(_ value: YAMLValue, indentation: String) -> [String] {
        switch value {
        case .list(let items):
            return items.flatMap { itemLines($0, indentation: indentation) }
        case .map(let entries):
            return entries.flatMap { entryLines(key: $0.key, value: $0.value, indentation: indentation) }
        case .null, .scalar:
            return []
        }
    }

    // MARK: - Characters

    private static func isControl(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0..<0x20, 0x7F...0x9F, 0x2028, 0x2029, 0xFEFF: return true
        default: return false
        }
    }

    private static func hexEscape(_ scalar: Unicode.Scalar) -> String {
        let (prefix, width) = scalar.value <= 0xFF ? ("\\x", 2) : ("\\u", 4)
        let digits = String(scalar.value, radix: 16, uppercase: true)
        return prefix + String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}
