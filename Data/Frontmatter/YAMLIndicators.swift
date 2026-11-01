import Foundation

/// The YAML indicator characters, one set each, shared by the scanner, the parsers and the serializer.
enum YAMLIndicators {
    /// They open, close and separate flow collections.
    static let flow: Set<Unicode.Scalar> = [",", "[", "]", "{", "}"]
    /// Indicators only when a space or the end follows (a block list item, a complex key, a mapping value).
    static let beforeSpace: Set<Unicode.Scalar> = ["-", "?", ":"]
    /// A comment, an anchor, an alias, a tag, a block scalar, a directive or a reserved character.
    static let nodeStarts: Set<Unicode.Scalar> = ["#", "&", "*", "!", "|", ">", "%", "@", "`"]
    static let quotes: Set<Unicode.Scalar> = ["'", "\""]
    /// What a value spanning lines starts with: a quoted scalar or a flow collection.
    static let multilineOpeners: Set<Unicode.Scalar> = quotes.union(["[", "{"])
}
