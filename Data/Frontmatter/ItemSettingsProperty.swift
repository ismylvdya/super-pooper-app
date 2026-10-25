import Foundation

/// The app's own settings of a task or habit (color, Show in Today, reminders, goal …) live in one property
/// holding JSON (`superpooper: '{"habit_color":"#34C759","show_in_today":true}'`), keyed by the same names the
/// separate properties had. Notes written before keep separate keys: they are read, and moved into the JSON
/// with the next change of any setting.
struct ItemSettingsProperty: Sendable {
    let property: String
    /// Frontmatter key names of the settings (`field-mapping.json` → `itemSettings.fields`).
    let keys: Set<String>

    /// The settings stored in the JSON, as frontmatter values; nil when the property is missing or not JSON.
    func values(in document: FrontmatterDocument) -> [String: YAMLValue]? {
        guard let object = object(in: document) else { return nil }
        return object.filter { keys.contains($0.key) }.compactMapValues(Self.yamlValue)
    }

    /// Sets (or with nil removes) one setting, moving the note's old separate setting keys into the JSON too.
    func set(_ key: String, to value: YAMLValue?, in document: inout FrontmatterDocument) {
        var object = object(in: document) ?? [:]
        for legacy in keys.sorted() where object[legacy] == nil {
            if let old = (try? document.value(for: legacy)).flatMap({ $0 }), let json = Self.jsonValue(old) { object[legacy] = json }
        }
        for legacy in keys { document.remove(legacy) }
        object[key] = value.flatMap(Self.jsonValue)
        guard !object.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]),
              let text = String(data: data, encoding: .utf8) else {
            document.remove(property)
            return
        }
        document.set(property, to: .scalar(text, quoted: true))
    }

    private func object(in document: FrontmatterDocument) -> [String: Any]? {
        guard let text = (try? document.value(for: property)).flatMap({ $0 })?.string, let data = text.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func yamlValue(_ json: Any) -> YAMLValue? {
        switch json {
        case let flag as NSNumber where CFGetTypeID(flag) == CFBooleanGetTypeID(): .bool(flag.boolValue)
        case let number as NSNumber: .scalar(number.stringValue, quoted: false)
        case let text as String: .scalar(text, quoted: true)
        case let items as [Any]: .list(items.compactMap(yamlValue))
        default: nil
        }
    }

    private static func jsonValue(_ value: YAMLValue) -> Any? {
        switch value {
        case .null, .map: return nil
        case .list(let items): return items.compactMap(jsonValue)
        case .scalar(let text, let quoted):
            guard !quoted else { return text }
            if let flag = value.bool { return flag }
            if let number = Int(text) { return number }
            return text
        }
    }
}
