import Foundation

struct YAMLMapEntry: Equatable, Sendable {
    let key: String
    let value: YAMLValue
}

/// A YAML node of the subset Obsidian frontmatter uses.
indirect enum YAMLValue: Equatable, Sendable {
    case null
    /// `quoted` means string semantics: the scalar was written in quotes, or has to be when serialized.
    case scalar(String, quoted: Bool)
    case list([YAMLValue])
    case map([YAMLMapEntry])

    /// A string scalar. Text that YAML would read back as null, a boolean or a number is marked quoted.
    static func string(_ text: String) -> YAMLValue {
        .scalar(text, quoted: readsAsNonString(text))
    }

    static func bool(_ value: Bool) -> YAMLValue {
        .scalar(value ? "true" : "false", quoted: false)
    }

    static func int(_ value: Int) -> YAMLValue {
        .scalar(String(value), quoted: false)
    }

    var string: String? {
        guard case .scalar(let text, _) = self else { return nil }
        return text
    }

    /// Plain `true` / `false` in any letter case; quoted text is a string, not a boolean.
    var bool: Bool? {
        guard case .scalar(let text, quoted: false) = self else { return nil }
        switch text.lowercased() {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    var int: Int? {
        string.flatMap { Int($0) }
    }

    var list: [YAMLValue]? {
        guard case .list(let items) = self else { return nil }
        return items
    }

    func value(for key: String) -> YAMLValue? {
        guard case .map(let entries) = self else { return nil }
        return entries.first { $0.key == key }?.value
    }

    private static func readsAsNonString(_ text: String) -> Bool {
        switch text.lowercased() {
        case "null", "~", "true", "false": return true
        default: return Int(text) != nil || Double(text) != nil
        }
    }
}
