import Foundation

/// A name in a config file that must be one of a fixed set: a typo is a config error listing the names it can be,
/// not a silent default.
protocol ConfigName: RawRepresentable, CaseIterable, Decodable, Sendable where RawValue == String {}

extension ConfigName {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let name = try container.decode(String.self)
        guard let value = Self(rawValue: name) else {
            let known = Self.allCases.map { "\"\($0.rawValue)\"" }.joined(separator: ", ")
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "unknown name \"\(name)\", expected one of \(known)")
        }
        self = value
    }
}

extension Decoder {
    /// Stops on a key the object does not have, so `"wieght"` is reported instead of being skipped.
    func rejectUnknownKeys<Keys: CodingKey>(_ keys: Keys.Type) throws {
        let container = try container(keyedBy: ConfigCodingKey.self)
        for key in container.allKeys where Keys(stringValue: key.stringValue) == nil {
            throw DecodingError.dataCorrupted(.init(codingPath: codingPath + [key], debugDescription: "unknown key \"\(key.stringValue)\" (typo?)"))
        }
    }
}

/// Any key of a config object, for reporting a key by name.
struct ConfigCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
