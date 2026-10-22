import Foundation

/// Extracts a note name from link forms found in frontmatter:
/// `[[Name]]`, `[[folder/Name|alias]]`, `[[Name#heading]]`, `[Alias](folder/Name.md)` and plain `Name`.
enum WikiLink {
    static func noteName(from raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("[["), text.hasSuffix("]]") {
            text = String(text.dropFirst(2).dropLast(2))
            text = String(text.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
        } else if text.hasPrefix("["), let open = text.range(of: "]("), text.hasSuffix(")") {
            text = String(text[open.upperBound..<text.index(before: text.endIndex)])
            text = text.removingPercentEncoding ?? text
        }
        text = String(text.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
        if let slash = text.lastIndex(of: "/") { text = String(text[text.index(after: slash)...]) }
        if text.lowercased().hasSuffix(".md") { text = String(text.dropLast(3)) }
        text = text.trimmingCharacters(in: .whitespaces).precomposedStringWithCanonicalMapping
        return text.isEmpty ? nil : text
    }

    static func make(_ name: String) -> String { "[[\(name.precomposedStringWithCanonicalMapping)]]" }
}
