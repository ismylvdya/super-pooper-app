import Foundation

/// Reads and writes small JSON files atomically. A missing or unreadable file is "no value":
/// everything stored by the app can be lost without harm (the truth lives in the vault).
struct JSONFileStore: Sendable {
    let directory: URL

    func url(_ name: String) -> URL { directory.appendingPathComponent(name) }

    func read<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? JSONDecoder.store.decode(type, from: data)
    }

    func readData(_ name: String) -> Data? { try? Data(contentsOf: url(name)) }

    func write<T: Encodable>(_ value: T, to name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder.store.encode(value).write(to: url(name), options: .atomic)
    }

    func writeData(_ data: Data, to name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url(name), options: .atomic)
    }

    func remove(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
    }
}

extension JSONEncoder {
    static var store: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var store: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
