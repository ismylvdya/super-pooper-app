import Foundation

/// Parses quoted scalars and flow collections (`[a, "b"]`, `{k: v}`). Multi-line values arrive joined with "\n".
struct YAMLFlowParser {
    private struct ScalarToken {
        let text: String
        let quoted: Bool

        var value: YAMLValue { quoted ? .scalar(text, quoted: true) : YAMLLineSyntax.plainScalarValue(text) }
    }

    private static let flowIndicators: Set<Unicode.Scalar> = [",", "[", "]", "{", "}"]
    private static let simpleEscapes: [Unicode.Scalar: Unicode.Scalar] = [
        "0": "\0", "a": "\u{07}", "b": "\u{08}", "t": "\t", "\t": "\t", "n": "\n", "v": "\u{0B}",
        "f": "\u{0C}", "r": "\r", "e": "\u{1B}", " ": " ", "\"": "\"", "/": "/", "\\": "\\",
        "N": "\u{85}", "_": "\u{A0}", "L": "\u{2028}", "P": "\u{2029}",
    ]
    private static let highSurrogates: ClosedRange<UInt32> = 0xD800...0xDBFF
    private static let lowSurrogates: ClosedRange<UInt32> = 0xDC00...0xDFFF

    private let scalars: [Unicode.Scalar]
    private let key: String
    private let firstLineNumber: Int
    private var index = 0

    init(_ text: Substring, key: String, firstLineNumber: Int) {
        self.scalars = Array(text.unicodeScalars)
        self.key = key
        self.firstLineNumber = firstLineNumber
    }

    /// Reads the quoted scalar `content` starts with; returns its text and whatever follows the closing quote.
    static func quotedPrefix(of content: Substring) -> (text: String, rest: Substring)? {
        var parser = YAMLFlowParser(content, key: "", firstLineNumber: 0)
        guard let text = try? parser.parseQuoted() else { return nil }
        return (text, Substring(content.unicodeScalars.dropFirst(parser.index)))
    }

    /// One node followed by nothing but whitespace and comments.
    mutating func parseCompleteValue() throws -> YAMLValue {
        skipWhitespaceAndComments()
        let value = try parseNode()
        skipWhitespaceAndComments()
        guard index == scalars.count else { throw failure("unexpected text after the value") }
        return value
    }

    // MARK: - Collections

    private mutating func parseNode() throws -> YAMLValue {
        if peek == "[" { return try parseSequence() }
        if peek == "{" { return try parseMapping() }
        return try parseScalarToken().value
    }

    private mutating func parseSequence() throws -> YAMLValue {
        let start = index
        index += 1
        var items: [YAMLValue] = []
        while true {
            skipWhitespaceAndComments()
            guard let scalar = peek else { throw failure("unterminated flow sequence", at: start) }
            if scalar == "]" {
                index += 1
                return .list(items)
            }
            items.append(try parseSequenceItem())
            try consumeSeparator(closing: "]", collectionStart: start, name: "flow sequence")
        }
    }

    /// An item, or a single-pair mapping such as `[key: value]`.
    private mutating func parseSequenceItem() throws -> YAMLValue {
        if peek == "[" || peek == "{" { return try parseNode() }
        let token = try parseScalarToken()
        skipWhitespaceAndComments()
        guard isMappingIndicator(afterQuotedKey: token.quoted) else { return token.value }
        index += 1
        return .map([YAMLMapEntry(key: token.text, value: try parseMappingValue())])
    }

    private mutating func parseMapping() throws -> YAMLValue {
        let start = index
        index += 1
        var entries: [YAMLMapEntry] = []
        while true {
            skipWhitespaceAndComments()
            guard let scalar = peek else { throw failure("unterminated flow mapping", at: start) }
            if scalar == "}" {
                index += 1
                return .map(entries)
            }
            guard scalar != "[", scalar != "{" else { throw failure("collection keys are not supported") }
            let key = try parseScalarToken()
            skipWhitespaceAndComments()
            var value = YAMLValue.null
            if isMappingIndicator(afterQuotedKey: key.quoted) {
                index += 1
                value = try parseMappingValue()
            }
            entries.append(YAMLMapEntry(key: key.text, value: value))
            try consumeSeparator(closing: "}", collectionStart: start, name: "flow mapping")
        }
    }

    private mutating func parseMappingValue() throws -> YAMLValue {
        skipWhitespaceAndComments()
        guard let scalar = peek, !Self.flowIndicators.contains(scalar) || scalar == "[" || scalar == "{" else { return .null }
        return try parseNode()
    }

    /// Consumes the `,` after an entry, or leaves the closing bracket for the caller.
    private mutating func consumeSeparator(closing: Unicode.Scalar, collectionStart: Int, name: String) throws {
        skipWhitespaceAndComments()
        guard let scalar = peek else { throw failure("unterminated \(name)", at: collectionStart) }
        if scalar == "," {
            index += 1
        } else if scalar != closing {
            throw failure("expected ',' or '\(closing)' in \(name)")
        }
    }

    private func isMappingIndicator(afterQuotedKey: Bool) -> Bool {
        peek == ":" && (afterQuotedKey || isSeparator(at: index + 1))
    }

    // MARK: - Scalars

    private mutating func parseScalarToken() throws -> ScalarToken {
        if peek == "\"" || peek == "'" {
            return ScalarToken(text: try parseQuoted(), quoted: true)
        }
        let text = parsePlain()
        guard !text.isEmpty else { throw failure("missing value") }
        return ScalarToken(text: text, quoted: false)
    }

    private mutating func parsePlain() -> String {
        var lines = [""]
        while let scalar = peek, !endsPlainScalar(scalar) {
            if scalar == "\n" {
                lines.append("")
            } else {
                lines[lines.count - 1].unicodeScalars.append(scalar)
            }
            index += 1
        }
        return YAMLLineSyntax.fold(lines.map { String(YAMLLineSyntax.trimmed(Substring($0))) })
    }

    private func endsPlainScalar(_ scalar: Unicode.Scalar) -> Bool {
        if Self.flowIndicators.contains(scalar) { return true }
        if scalar == ":" { return isSeparator(at: index + 1) }
        if scalar == "#" { return index > 0 && Self.isSpace(scalars[index - 1]) }
        return false
    }

    private mutating func parseQuoted() throws -> String {
        guard let quote = peek, quote == "\"" || quote == "'" else { throw failure("expected a quoted string") }
        let start = index
        index += 1
        var text = String.UnicodeScalarView()
        var pendingSpaces = String.UnicodeScalarView()
        while let scalar = peek {
            index += 1
            switch scalar {
            case quote where quote == "'" && peek == "'":
                index += 1
                text.append(contentsOf: pendingSpaces)
                pendingSpaces = String.UnicodeScalarView()
                text.append("'")
            case quote:
                text.append(contentsOf: pendingSpaces)
                return String(text)
            case "\\" where quote == "\"":
                text.append(contentsOf: pendingSpaces)
                pendingSpaces = String.UnicodeScalarView()
                if peek == "\n" {
                    index += 1
                    skipLineIndent()
                } else {
                    text.append(try parseEscape())
                }
            case " ", "\t":
                pendingSpaces.append(scalar)
            case "\n":
                pendingSpaces = String.UnicodeScalarView()
                text.append(contentsOf: foldedLineBreak().unicodeScalars)
            default:
                text.append(contentsOf: pendingSpaces)
                pendingSpaces = String.UnicodeScalarView()
                text.append(scalar)
            }
        }
        let style = quote == "\"" ? "double" : "single"
        throw failure("unterminated \(style)-quoted string", at: start)
    }

    /// Called after a line break inside quotes: skips indentation and counts the empty lines that follow.
    private mutating func foldedLineBreak() -> String {
        skipLineIndent()
        var emptyLines = 0
        while peek == "\n" {
            emptyLines += 1
            index += 1
            skipLineIndent()
        }
        return emptyLines == 0 ? " " : String(repeating: "\n", count: emptyLines)
    }

    private mutating func parseEscape() throws -> Unicode.Scalar {
        guard let code = peek else { throw failure("unterminated double-quoted string") }
        index += 1
        if let simple = Self.simpleEscapes[code] { return simple }
        switch code {
        case "x": return try scalar(from: readHex(digits: 2))
        case "U": return try scalar(from: readHex(digits: 8))
        case "u":
            let value = try readHex(digits: 4)
            guard Self.highSurrogates.contains(value), peek == "\\", peek(at: index + 1) == "u" else {
                return try scalar(from: value)
            }
            index += 2
            let low = try readHex(digits: 4)
            guard Self.lowSurrogates.contains(low) else { throw failure("invalid surrogate pair") }
            return try scalar(from: 0x10000 + ((value - 0xD800) << 10) + (low - 0xDC00))
        default:
            throw failure("invalid escape sequence \\\(code)")
        }
    }

    private mutating func readHex(digits: Int) throws -> UInt32 {
        guard index + digits <= scalars.count else { throw failure("invalid escape sequence") }
        var value: UInt32 = 0
        for scalar in scalars[index..<index + digits] {
            guard scalar.isASCII, let digit = Character(scalar).hexDigitValue else { throw failure("invalid escape sequence") }
            value = value * 16 + UInt32(digit)
        }
        index += digits
        return value
    }

    private func scalar(from value: UInt32) throws -> Unicode.Scalar {
        guard let scalar = Unicode.Scalar(value) else { throw failure("invalid escape sequence") }
        return scalar
    }

    // MARK: - Cursor

    private var peek: Unicode.Scalar? { peek(at: index) }

    private func peek(at position: Int) -> Unicode.Scalar? {
        position < scalars.count ? scalars[position] : nil
    }

    private static func isSpace(_ scalar: Unicode.Scalar) -> Bool {
        scalar == " " || scalar == "\t" || scalar == "\n"
    }

    /// End of text, whitespace, a line break or a flow indicator.
    private func isSeparator(at position: Int) -> Bool {
        guard let scalar = peek(at: position) else { return true }
        return Self.isSpace(scalar) || Self.flowIndicators.contains(scalar)
    }

    private mutating func skipLineIndent() {
        while let scalar = peek, YAMLLineSyntax.isWhitespace(scalar) { index += 1 }
    }

    private mutating func skipWhitespaceAndComments() {
        while let scalar = peek {
            if Self.isSpace(scalar) {
                index += 1
            } else if scalar == "#" && (index == 0 || Self.isSpace(scalars[index - 1])) {
                while let next = peek, next != "\n" { index += 1 }
            } else {
                return
            }
        }
    }

    private func failure(_ reason: String, at position: Int? = nil) -> FrontmatterError {
        let end = min(position ?? index, scalars.count)
        let breaks = scalars[..<end].reduce(0) { $1 == "\n" ? $0 + 1 : $0 }
        return .malformedValue(key: key, line: firstLineNumber + breaks, reason: reason)
    }
}
