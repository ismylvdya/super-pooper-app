import Foundation

/// A config file that could not be read. The message names the file and the key path,
/// so a typo is easy to find.
struct ConfigError: Error, CustomStringConvertible, Sendable {
    let file: String
    let path: String
    let message: String

    var description: String {
        path.isEmpty ? "\(file): \(message)" : "\(file) → \(path): \(message)"
    }
}

/// Loads bundled JSON configs (`Resources/Config`).
struct ConfigLoader: Sendable {
    let bundle: Bundle

    func data(_ file: String) throws -> Data {
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        guard let url = bundle.url(forResource: name, withExtension: ext.isEmpty ? "json" : ext) else {
            throw ConfigError(file: file, path: "", message: "file is missing from the app bundle")
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw ConfigError(file: file, path: "", message: error.localizedDescription)
        }
    }

    func load<T: Decodable>(_ type: T.Type, from file: String) throws -> T {
        try ConfigLoader.decode(type, from: data(file), file: file)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data, file: String) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as DecodingError {
            throw ConfigError(decodingError: error, file: file)
        } catch let error as ConfigError {
            throw error
        } catch {
            throw ConfigError(file: file, path: "", message: error.localizedDescription)
        }
    }
}

extension ConfigError {
    init(decodingError: DecodingError, file: String) {
        func path(_ context: DecodingError.Context) -> String {
            context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? $0.stringValue }.joined(separator: ".")
        }
        switch decodingError {
        case .keyNotFound(let key, let context):
            self.init(file: file, path: path(context), message: "missing key \"\(key.stringValue)\"")
        case .typeMismatch(let type, let context):
            self.init(file: file, path: path(context), message: "expected \(type): \(context.debugDescription)")
        case .valueNotFound(let type, let context):
            self.init(file: file, path: path(context), message: "missing value of type \(type)")
        case .dataCorrupted(let context):
            self.init(file: file, path: path(context), message: context.debugDescription)
        @unknown default:
            self.init(file: file, path: "", message: decodingError.localizedDescription)
        }
    }
}
