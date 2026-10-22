import Foundation

/// One line of a value block: the leading spaces are counted, the rest is `content`.
struct YAMLSourceLine {
    let number: Int
    let indent: Int
    let content: Substring

    init(number: Int, indent: Int, content: Substring) {
        self.number = number
        self.indent = indent
        self.content = content
    }

    init(number: Int, text: Substring) {
        let indent = text.unicodeScalars.prefix { $0 == " " }.count
        self.init(number: number, indent: indent, content: Substring(text.unicodeScalars.dropFirst(indent)))
    }

    var text: String { String(repeating: " ", count: indent) + content }
    var isBlank: Bool { YAMLLineSyntax.isBlank(content) }
    var isComment: Bool { content.unicodeScalars.first == "#" }
    var isSequenceEntry: Bool { YAMLLineSyntax.isSequenceEntry(content) }
}

/// Line-level YAML syntax shared by the frontmatter scanner, the value parsers and the serializer.
enum YAMLLineSyntax {
    struct MappingEntry {
        let key: String
        /// Everything after the `:` indicator, untrimmed.
        let value: Substring
    }

    private static let plainKeyForbiddenStarts: Set<Unicode.Scalar> = ["[", "]", "{", "}", "#", "|", ">", "!", "&", "*", "%", "@", "`", ","]
    private static let indicatorsNeedingSpace: Set<Unicode.Scalar> = ["-", "?", ":"]

    static func isWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        scalar == " " || scalar == "\t"
    }

    static func isBlank(_ text: Substring) -> Bool {
        text.unicodeScalars.allSatisfy(isWhitespace)
    }

    /// `-` alone or followed by whitespace.
    static func isSequenceEntry(_ content: Substring) -> Bool {
        let scalars = content.unicodeScalars
        guard scalars.first == "-" else { return false }
        return scalars.dropFirst().first.map(isWhitespace) ?? true
    }

    static func trimmed(_ text: Substring) -> Substring {
        let scalars = text.unicodeScalars
        guard let start = scalars.firstIndex(where: { !isWhitespace($0) }),
              let last = scalars.lastIndex(where: { !isWhitespace($0) }) else { return "" }
        return Substring(scalars[start...last])
    }

    static func droppingTrailingWhitespace(_ text: Substring) -> Substring {
        let scalars = text.unicodeScalars
        guard let last = scalars.lastIndex(where: { !isWhitespace($0) }) else { return "" }
        return Substring(scalars[...last])
    }

    /// Cuts a ` # comment` off plain text and trims it.
    static func strippingComment(_ text: Substring) -> (text: Substring, hadComment: Bool) {
        let scalars = text.unicodeScalars
        var previous: Unicode.Scalar = " "
        for index in scalars.indices {
            if scalars[index] == "#" && isWhitespace(previous) {
                return (trimmed(Substring(scalars[..<index])), true)
            }
            previous = scalars[index]
        }
        return (trimmed(text), false)
    }

    /// Splits `key: value` with a plain or quoted key; nil when `content` is not a mapping entry.
    static func mappingEntry(in content: Substring) -> MappingEntry? {
        let scalars = content.unicodeScalars
        guard let first = scalars.first else { return nil }
        if first == "\"" || first == "'" {
            return quotedKeyEntry(in: content)
        }
        if plainKeyForbiddenStarts.contains(first) { return nil }
        if indicatorsNeedingSpace.contains(first), scalars.dropFirst().first.map(isWhitespace) ?? true { return nil }

        var previous: Unicode.Scalar = " "
        var index = scalars.startIndex
        while index < scalars.endIndex {
            let scalar = scalars[index]
            let next = scalars.index(after: index)
            if scalar == "#" && isWhitespace(previous) { return nil }
            if scalar == ":" && (next == scalars.endIndex || isWhitespace(scalars[next])) {
                let key = droppingTrailingWhitespace(Substring(scalars[..<index]))
                return key.isEmpty ? nil : MappingEntry(key: String(key), value: Substring(scalars[next...]))
            }
            previous = scalar
            index = next
        }
        return nil
    }

    /// YAML core schema nulls; any other plain text stays a plain scalar.
    static func plainScalarValue(_ text: String) -> YAMLValue {
        switch text {
        case "", "~", "null", "Null", "NULL": return .null
        default: return .scalar(text, quoted: false)
        }
    }

    /// YAML line folding: a single break between text lines becomes a space, each empty line a newline,
    /// and lines starting with whitespace keep their breaks. Trailing empty lines are dropped.
    static func fold(_ lines: [String]) -> String {
        var result = ""
        var hasText = false
        var emptyLines = 0
        var previousIsIndented = false
        for line in lines {
            guard let first = line.unicodeScalars.first else {
                emptyLines += 1
                continue
            }
            let isIndented = isWhitespace(first)
            if !hasText {
                result += String(repeating: "\n", count: emptyLines)
            } else if isIndented || previousIsIndented {
                result += String(repeating: "\n", count: emptyLines + 1)
            } else {
                result += emptyLines == 0 ? " " : String(repeating: "\n", count: emptyLines)
            }
            result += line
            hasText = true
            emptyLines = 0
            previousIsIndented = isIndented
        }
        return result
    }

    private static func quotedKeyEntry(in content: Substring) -> MappingEntry? {
        guard let quoted = YAMLFlowParser.quotedPrefix(of: content) else { return nil }
        let rest = quoted.rest.unicodeScalars.drop(while: isWhitespace)
        guard rest.first == ":" else { return nil }
        let value = rest.dropFirst()
        guard value.first.map(isWhitespace) ?? true else { return nil }
        return MappingEntry(key: quoted.text, value: Substring(value))
    }
}
