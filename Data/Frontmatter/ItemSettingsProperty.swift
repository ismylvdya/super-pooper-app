import Foundation

/// The app's own settings of a task or habit (color, Show in Today, reminders, goal …) live in one property
/// holding JSON (`fromSuperPooperApp: '{"habit_color":"#34C759","show_in_today":true}'`), keyed by the same names the
/// separate properties had. Notes written before keep separate keys: they are read, and moved into the JSON
/// with the next change of any setting (or by the sync's migration), as are notes with the property's older name.
struct ItemSettingsProperty: Sendable {
    let property: String
    var legacyProperties: [String] = []
    /// Frontmatter key names of the settings (`field-mapping.json` → `itemSettings.fields`).
    let keys: Set<String>

    init(property: String, legacyProperties: [String] = [], keys: Set<String>) {
        self.property = property
        self.legacyProperties = legacyProperties
        self.keys = keys
    }

    init(mapping: FieldMapping) {
        self.init(property: mapping.itemSettings.property, legacyProperties: mapping.itemSettings.legacyProperties,
                  keys: mapping.itemSettingsKeys)
    }

    /// The note keeps a setting outside the JSON or the JSON under an older name.
    func hasLegacyKeys(in document: FrontmatterDocument) -> Bool {
        (keys.union(legacyProperties)).contains { (try? document.value(for: $0)).flatMap({ $0 }) != nil }
    }

    /// Moves every old-format setting into the JSON, changing no value.
    func migrate(in document: inout FrontmatterDocument) {
        guard hasLegacyKeys(in: document) else { return }
        write(object(in: document) ?? [:], in: &document)
    }

    /// The settings stored in the JSON, as frontmatter values; nil when the property is missing or not JSON.
    func values(in document: FrontmatterDocument) -> [String: YAMLValue]? {
        guard let object = object(in: document) else { return nil }
        return object.filter { keys.contains($0.key) }.compactMapValues(Self.yamlValue)
    }

    /// Sets (or with nil removes) one setting, moving the note's old separate setting keys into the JSON too.
    func set(_ key: String, to value: YAMLValue?, in document: inout FrontmatterDocument) {
        var object = object(in: document) ?? [:]
        object[key] = value.flatMap(Self.jsonValue)
        write(object, in: &document, keeping: key)
    }

    /// Writes the JSON with the note's separate setting keys folded in (`keeping` one already set wins) and the
    /// older property names removed.
    private func write(_ settings: [String: Any], in document: inout FrontmatterDocument, keeping kept: String? = nil) {
        var object = settings
        for legacy in keys.sorted() where legacy != kept && object[legacy] == nil {
            if let old = (try? document.value(for: legacy)).flatMap({ $0 }), let json = Self.jsonValue(old) { object[legacy] = json }
        }
        for legacy in keys { document.remove(legacy) }
        for name in legacyProperties { document.remove(name) }
        guard !object.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]),
              let text = String(data: data, encoding: .utf8) else {
            document.remove(property)
            return
        }
        document.set(property, to: .scalar(text, quoted: true))
    }

    private func object(in document: FrontmatterDocument) -> [String: Any]? {
        for name in [property] + legacyProperties {
            if let object = object(named: name, in: document) { return object }
        }
        return nil
    }

    private func object(named property: String, in document: FrontmatterDocument) -> [String: Any]? {
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
