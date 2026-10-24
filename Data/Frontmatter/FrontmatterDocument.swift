import Foundation

enum FrontmatterError: Error, Equatable, Sendable {
    case noFrontmatter
    case unterminated
    case malformedLine(line: Int, text: String)
    case malformedValue(key: String, line: Int, reason: String)
}

/// A note's YAML frontmatter. Editing a key rewrites only that key's lines; every other byte of the file,
/// including comments, blank lines, line endings and the body, stays as it was.
/// Line numbers in errors are 1-based and count the opening `---` as line 1.
struct FrontmatterDocument: Sendable {
    private let opening: String
    private var blocks: [FrontmatterBlock]
    private let closing: String
    private let lineEnding: String
    let body: String

    init(text: String) throws {
        let layout = try FrontmatterScanner.scan(text)
        opening = layout.opening
        blocks = layout.blocks
        closing = layout.closing
        lineEnding = layout.lineEnding
        body = layout.body
    }

    /// Top-level keys in file order; a duplicated key is listed once.
    var keys: [String] {
        var seen = Set<String>()
        return blocks.compactMap(\.key).filter { seen.insert($0).inserted }
    }

    var text: String {
        opening + blocks.flatMap(\.lines).map(\.text).joined() + closing + body
    }

    /// The note with this frontmatter and another body. A closing `---` at the very end of the file has no
    /// line ending yet; it gets one before a body.
    func text(withBody newBody: String) -> String {
        var head = opening + blocks.flatMap(\.lines).map(\.text).joined() + closing
        if !newBody.isEmpty, !head.hasSuffix("\n") { head += lineEnding }
        return head + newBody
    }

    /// The key's lines exactly as they are in the file, line breaks included.
    func rawValue(for key: String) -> String? {
        blocks.first { $0.key == key }.map { $0.lines.map(\.text).joined() }
    }

    func value(for key: String) throws -> YAMLValue? {
        guard let index = blocks.firstIndex(where: { $0.key == key }) else { return nil }
        let lineNumber = firstLineNumber(ofBlockAt: index)
        let lines = blocks[index].lines
        guard let keyLine = lines.first, let entry = YAMLLineSyntax.mappingEntry(in: Substring(keyLine.content)) else {
            throw FrontmatterError.malformedValue(key: key, line: lineNumber, reason: "missing key line")
        }
        return try YAMLSubsetParser.parse(
            key: key,
            inlineValue: entry.value,
            lineNumber: lineNumber,
            followingLines: lines.dropFirst().map(\.content)
        )
    }

    /// Replaces the first block of `key` in place, or appends the key at the end of the frontmatter.
    mutating func set(_ key: String, to value: YAMLValue) {
        let lines = YAMLSerializer.lines(key: key, value: value).map { FrontmatterLine(content: $0, ending: lineEnding) }
        let block = FrontmatterBlock(key: key, lines: lines)
        if let index = blocks.firstIndex(where: { $0.key == key }) {
            blocks[index] = block
        } else {
            blocks.append(block)
        }
    }

    /// Removes the key's lines (every copy of a duplicated key); surrounding comments and blank lines stay.
    mutating func remove(_ key: String) {
        blocks.removeAll { $0.key == key }
    }

    private func firstLineNumber(ofBlockAt index: Int) -> Int {
        blocks[..<index].reduce(FrontmatterScanner.firstBlockLineNumber) { $0 + $1.lines.count }
    }
}
