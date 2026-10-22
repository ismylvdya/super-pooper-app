import Foundation

struct FrontmatterLine: Sendable {
    let content: String
    /// "\n", "\r\n", or "" for a last line without a line break.
    let ending: String

    var text: String { content + ending }
}

/// The lines of one top-level key, or blank and comment lines between keys (`key == nil`).
struct FrontmatterBlock: Sendable {
    let key: String?
    var lines: [FrontmatterLine]
}

struct FrontmatterLayout: Sendable {
    /// Byte order mark (if any) and the opening delimiter line with its line break.
    let opening: String
    let blocks: [FrontmatterBlock]
    let closing: String
    let body: String
    let lineEnding: String
}

/// Splits a note into delimiters, top-level key blocks and body, and checks the frontmatter structure
/// without parsing values.
enum FrontmatterScanner {
    static let firstBlockLineNumber = 2
    private static let byteOrderMark: Unicode.Scalar = "\u{FEFF}"
    private static let valueOpeners: Set<Unicode.Scalar> = ["\"", "'", "[", "{"]

    static func scan(_ text: String) throws -> FrontmatterLayout {
        var reader = LineReader(text)
        let byteOrderMark = reader.skip(Self.byteOrderMark) ? String(Self.byteOrderMark) : ""
        guard let opening = reader.next(), isDelimiter(opening.content, allowsDots: false) else {
            throw FrontmatterError.noFrontmatter
        }
        var lines: [FrontmatterLine] = []
        var closing: FrontmatterLine?
        while closing == nil {
            guard let line = reader.next() else { throw FrontmatterError.unterminated }
            if isDelimiter(line.content, allowsDots: true) {
                closing = line
            } else {
                lines.append(line)
            }
        }
        let blocks = try groupIntoBlocks(lines)
        try validateInlineValues(of: blocks)
        return FrontmatterLayout(
            opening: byteOrderMark + opening.text,
            blocks: blocks,
            closing: closing?.text ?? "",
            body: reader.remainder,
            lineEnding: opening.ending == "\r\n" ? "\r\n" : "\n"
        )
    }

    private static func isDelimiter(_ content: String, allowsDots: Bool) -> Bool {
        let marker = YAMLLineSyntax.droppingTrailingWhitespace(Substring(content))
        return marker == "---" || (allowsDots && marker == "...")
    }

    /// Every line at column 0 is a key, a `- ` item of the previous key, a comment or blank; indented lines
    /// belong to the previous key. Blank and comment lines after a block's last line stay outside the block.
    private static func groupIntoBlocks(_ lines: [FrontmatterLine]) throws -> [FrontmatterBlock] {
        var blocks: [FrontmatterBlock] = []
        var current: FrontmatterBlock?
        var acceptsColumnZeroItems = false
        var unassigned: [FrontmatterLine] = []

        for (offset, line) in lines.enumerated() {
            let content = Substring(line.content)
            let first = content.unicodeScalars.first
            if YAMLLineSyntax.isBlank(content) || first == "#" {
                unassigned.append(line)
                continue
            }
            let malformed = FrontmatterError.malformedLine(line: firstBlockLineNumber + offset, text: line.content)
            if first == " " || YAMLLineSyntax.isSequenceEntry(content) {
                guard current != nil, first == " " || acceptsColumnZeroItems else { throw malformed }
                current?.lines += unassigned + [line]
                unassigned = []
                continue
            }
            guard first != "\t", let entry = YAMLLineSyntax.mappingEntry(in: content) else { throw malformed }
            if let finished = current { blocks.append(finished) }
            if !unassigned.isEmpty { blocks.append(FrontmatterBlock(key: nil, lines: unassigned)) }
            unassigned = []
            current = FrontmatterBlock(key: entry.key, lines: [line])
            acceptsColumnZeroItems = YAMLLineSyntax.strippingComment(entry.value).text.isEmpty
        }
        if let finished = current { blocks.append(finished) }
        if !unassigned.isEmpty { blocks.append(FrontmatterBlock(key: nil, lines: unassigned)) }
        return blocks
    }

    /// Quoted and flow values must be closed, including ones that continue on indented lines.
    private static func validateInlineValues(of blocks: [FrontmatterBlock]) throws {
        var lineNumber = firstBlockLineNumber
        for block in blocks {
            defer { lineNumber += block.lines.count }
            guard let key = block.key,
                  let keyLine = block.lines.first,
                  let entry = YAMLLineSyntax.mappingEntry(in: Substring(keyLine.content)) else { continue }
            let value = YAMLLineSyntax.trimmed(entry.value)
            guard let first = value.unicodeScalars.first, valueOpeners.contains(first) else { continue }
            let text = ([String(value)] + block.lines.dropFirst().map(\.content)).joined(separator: "\n")
            if let problem = YAMLBalanceScanner.problem(in: text) {
                throw FrontmatterError.malformedValue(key: key, line: lineNumber + problem.lineOffset, reason: problem.reason)
            }
        }
    }
}

/// Reads lines by Unicode scalars, so "\r\n" splits like "\n" and the bytes of every line are kept exactly.
private struct LineReader {
    private let scalars: String.UnicodeScalarView
    private var cursor: String.Index

    init(_ text: String) {
        scalars = text.unicodeScalars
        cursor = scalars.startIndex
    }

    var remainder: String { String(scalars[cursor...]) }

    mutating func skip(_ scalar: Unicode.Scalar) -> Bool {
        guard cursor < scalars.endIndex, scalars[cursor] == scalar else { return false }
        cursor = scalars.index(after: cursor)
        return true
    }

    mutating func next() -> FrontmatterLine? {
        guard cursor < scalars.endIndex else { return nil }
        guard let newline = scalars[cursor...].firstIndex(of: "\n") else {
            let line = FrontmatterLine(content: remainder, ending: "")
            cursor = scalars.endIndex
            return line
        }
        var contentEnd = newline
        if newline > cursor {
            let beforeNewline = scalars.index(before: newline)
            if scalars[beforeNewline] == "\r" { contentEnd = beforeNewline }
        }
        let afterNewline = scalars.index(after: newline)
        let line = FrontmatterLine(content: String(scalars[cursor..<contentEnd]), ending: String(scalars[contentEnd..<afterNewline]))
        cursor = afterNewline
        return line
    }
}
