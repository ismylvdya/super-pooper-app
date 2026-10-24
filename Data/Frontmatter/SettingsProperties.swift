import Foundation

/// App settings as note properties: every JSON leaf is one frontmatter key named by its path
/// (`timeline.hoursBefore: 2`, `habits.morningRoutine: [Душ]`), so Obsidian shows and edits each one.
enum SettingsProperties {
    struct Property: Equatable {
        let key: String
        let value: YAMLValue
    }

    static let separator: Character = "."

    /// The leaves of a JSON object, sorted by path. Empty objects have no leaves and are left out.
    static func properties(from json: Data) throws -> [Property] {
        var result: [Property] = []
        flatten(try JSONSerialization.jsonObject(with: json), path: "", into: &result)
        return result
    }

    /// Top-level keys of a JSON object: the property paths that belong to the settings.
    static func roots(of json: Data) throws -> Set<String> {
        Set(((try JSONSerialization.jsonObject(with: json)) as? [String: Any] ?? [:]).keys)
    }

    /// A JSON object rebuilt from properties; paths that are not settings are dropped later by decoding.
    static func json(from properties: [Property]) throws -> Data {
        var root: [String: Any] = [:]
        for property in properties {
            insert(jsonValue(property.value), at: property.key.split(separator: separator).map(String.init)[...], into: &root)
        }
        return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    }

    static func root(of key: String) -> String {
        String(key.prefix { $0 != separator })
    }

    // MARK: - JSON → properties

    private static func flatten(_ value: Any, path: String, into result: inout [Property]) {
        if let object = value as? [String: Any] {
            for key in object.keys.sorted() {
                flatten(object[key]!, path: path.isEmpty ? key : "\(path)\(separator)\(key)", into: &result)
            }
        } else if let items = value as? [Any] {
            result.append(Property(key: path, value: .list(items.map(scalar))))
        } else {
            result.append(Property(key: path, value: scalar(value)))
        }
    }

    private static func scalar(_ value: Any) -> YAMLValue {
        switch value {
        case let number as NSNumber where CFGetTypeID(number) == CFBooleanGetTypeID(): .bool(number.boolValue)
        case let number as NSNumber: .scalar(number.stringValue, quoted: false)
        case let text as String: .string(text)
        case is NSNull: .null
        default: .string(String(describing: value))
        }
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
