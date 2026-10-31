import Foundation

/// App settings as the older settings note kept them: every JSON leaf one frontmatter key named by its path
/// (`timeline.hoursBefore: 2`, `habits.morningRoutine: [Душ]`). Only read now: the settings live in a JSON file.
enum SettingsProperties {
    struct Property: Equatable {
        let key: String
        let value: YAMLValue
    }

    static let separator: Character = "."

    /// A JSON object rebuilt from properties; paths that are not settings are dropped later by decoding.
    static func json(from properties: [Property]) throws -> Data {
        var root: [String: Any] = [:]
        for property in properties {
            insert(jsonValue(property.value), at: property.key.split(separator: separator).map(String.init)[...], into: &root)
        }
        return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    }

    // MARK: - Properties → JSON

    private static func jsonValue(_ value: YAMLValue) -> Any {
        switch value {
        case .null: NSNull()
        case .scalar(let text, quoted: true): text
        case .scalar(let text, quoted: false):
            value.bool.map { $0 as Any } ?? Int(text).map { $0 as Any } ?? Double(text).map { $0 as Any } ?? text
        case .list(let items): items.map(jsonValue)
        case .map(let entries): Dictionary(entries.map { ($0.key, jsonValue($0.value)) }, uniquingKeysWith: { first, _ in first })
        }
    }

    private static func insert(_ value: Any, at path: ArraySlice<String>, into object: inout [String: Any]) {
        guard let key = path.first else { return }
        guard path.count > 1 else {
            object[key] = value
            return
        }
        var child = object[key] as? [String: Any] ?? [:]
        insert(value, at: path.dropFirst(), into: &child)
        object[key] = child
    }
}
