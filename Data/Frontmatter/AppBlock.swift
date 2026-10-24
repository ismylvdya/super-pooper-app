import Foundation

/// The app's own block in a note body: a fenced code block ```SuperPooperApp … ``` right after the
/// frontmatter, holding JSON. The app shows and edits only the text around it; the block is kept as is.
enum AppBlock {
    static let fence = "```"
    static let language = "SuperPooperApp"

    struct Split: Equatable {
        /// The block with its fences and the line break after it, or "" when there is none.
        let block: String
        /// Everything else: what the description fields show.
        let visible: String
    }

    static func split(_ body: String) -> Split {
        let opening = fence + language
        let leading = body.prefix { $0 == "\n" || $0 == "\r" }
        let rest = body.dropFirst(leading.count)
        guard rest.hasPrefix(opening + "\n") || rest.hasPrefix(opening + "\r\n"),
              let close = rest.range(of: "\n" + fence, range: rest.index(rest.startIndex, offsetBy: opening.count)..<rest.endIndex) else {
            return Split(block: "", visible: body)
        }
        var end = close.upperBound
        while end < rest.endIndex, rest[end] == "\n" || rest[end] == "\r" { end = rest.index(after: end) }
        return Split(block: String(body[body.startIndex..<end]), visible: String(rest[end...]))
    }

    /// The body with `visible` text after the existing block (the block stays first).
    static func join(block: String, visible: String) -> String {
        guard !block.isEmpty else { return visible }
        let separator = block.hasSuffix("\n\n") || visible.isEmpty ? "" : (block.hasSuffix("\n") ? "\n" : "\n\n")
        return block + separator + visible
    }

    /// The JSON inside a block, if the body starts with one.
    static func json(in body: String) -> Data? {
        let block = split(body).block
        guard !block.isEmpty, let start = block.firstIndex(of: "\n"), let end = block.range(of: "\n" + fence, options: .backwards) else {
            return nil
        }
        return Data(block[block.index(after: start)..<end.lowerBound].utf8)
    }

    /// A block holding `json`.
    static func make(json: Data) -> String {
        "\(fence)\(language)\n\(String(decoding: json, as: UTF8.self))\n\(fence)\n"
    }
}
