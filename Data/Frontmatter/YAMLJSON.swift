import Foundation

/// Frontmatter values as JSON objects and back: the one bridge between the two (item settings, the older settings note).
enum YAMLJSON {
    /// Null as `NSNull`, a quoted scalar as a string, an unquoted one typed (boolean, integer, finite number) or a string;
    /// lists and maps as arrays and dictionaries.
    static func json(_ value: YAMLValue) -> Any {
        switch value {
        case .null: NSNull()
        case .scalar(let text, quoted: true): text
        case .scalar(let text, quoted: false):
            value.bool.map { $0 as Any } ?? Int(text).map { $0 as Any } ?? Double(text).flatMap { $0.isFinite ? $0 as Any : nil } ?? text
        case .list(let items): items.map(json)
        case .map(let entries): Dictionary(entries.map { ($0.key, json($0.value)) }, uniquingKeysWith: { first, _ in first })
        }
    }

    /// A JSON value as a frontmatter value: strings quoted, booleans and numbers plain, arrays as lists; nil for null and
    /// objects.
    static func yaml(_ json: Any) -> YAMLValue? {
        switch json {
        case let flag as NSNumber where CFGetTypeID(flag) == CFBooleanGetTypeID(): .bool(flag.boolValue)
        case let number as NSNumber: .scalar(number.stringValue, quoted: false)
        case let text as String: .scalar(text, quoted: true)
        case let items as [Any]: .list(items.compactMap(yaml))
        default: nil
        }
    }
}
