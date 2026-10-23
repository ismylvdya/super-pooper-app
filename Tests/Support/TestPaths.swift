import Foundation
@testable import SuperPooper

/// Project files the tests read: the test vault templates and the real JSON configs.
/// The root is found by walking up from this file (symlinks resolved first), so the tests work
/// from Xcode, from a scratch SwiftPM package that links the sources, and from the simulator.
enum TestPaths {
    static let projectRoot: URL = locateProjectRoot(from: #filePath)

    static var testVault: URL { projectRoot.appendingPathComponent("Fixtures/TestVault", isDirectory: true) }
    static var configFolder: URL { projectRoot.appendingPathComponent("Resources/Config", isDirectory: true) }

    private static func locateProjectRoot(from file: String) -> URL {
        let path = URL(fileURLWithPath: file)
        for start in [path.resolvingSymlinksInPath(), path] {
            var folder = start.deletingLastPathComponent()
            while folder.pathComponents.count > 1 {
                let marker = folder.appendingPathComponent("Fixtures/TestVault", isDirectory: true)
                if FileManager.default.fileExists(atPath: marker.path) { return folder }
                folder.deleteLastPathComponent()
            }
        }
        preconditionFailure("Fixtures/TestVault not found above \(file)")
    }
}

/// The real configs from `Resources/Config`, so tests follow whatever the app ships with.
enum TestConfig {
    static let mapping = decode(FieldMapping.self, "field-mapping.json")
    static let rules = decode(RulesConfig.self, "rules.json")
    static let sort = decode(SortConfig.self, "sort.json")
    static let defaults = decode(AppSettings.self, "defaults.json")
    static let actions = decode(ActionRegistry.self, "actions.json")

    static func decode<T: Decodable>(_ type: T.Type, _ file: String) -> T {
        do {
            let data = try Data(contentsOf: TestPaths.configFolder.appendingPathComponent(file))
            return try JSONDecoder().decode(type, from: data)
        } catch {
            preconditionFailure("\(file) does not decode: \(error)")
        }
    }
}
