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
            insert(YAMLJSON.json(property.value), at: property.key.split(separator: separator).map(String.init)[...], into: &root)
        }
        return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
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
