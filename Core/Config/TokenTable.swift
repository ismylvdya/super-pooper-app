import Foundation

/// A config dictionary keyed by an enum: every key must be present and unknown keys are
/// reported, so a typo in JSON surfaces as a clear error instead of a silent default.
struct TokenTable<Key: Hashable & CaseIterable & RawRepresentable & Sendable, Value: Sendable>: Sendable
where Key.RawValue == String {
    private let values: [Key: Value]

    init(_ values: [Key: Value]) { self.values = values }

    /// The same table with some values replaced.
    func replacing(_ overrides: [Key: Value]) -> TokenTable {
        TokenTable(values.merging(overrides) { _, new in new })
    }

    subscript(key: Key) -> Value {
        guard let value = values[key] else { preconditionFailure("TokenTable was validated on decode: \(key.rawValue)") }
        return value
    }
}

extension TokenTable: Decodable where Value: Decodable {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode([String: Value].self)
        for key in raw.keys where Key(rawValue: key) == nil {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "unknown key \"\(key)\" (typo?)"))
        }
        var values: [Key: Value] = [:]
        for key in Key.allCases {
            guard let value = raw[key.rawValue] else {
                throw DecodingError.keyNotFound(TokenCodingKey(stringValue: key.rawValue),
                                                .init(codingPath: decoder.codingPath, debugDescription: "missing token"))
            }
            values[key] = value
        }
        self.values = values
    }
}

private struct TokenCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
