import Foundation
import Testing
@testable import SuperPooperApp

/// A misspelt font or color value in tokens.json stops the app with the config error screen naming the token, instead
/// of a silent regular weight or a black color.
struct TokenValidationTests {
    @Test func theBundledTokensLoad() throws {
        #expect(try configError(setting: [], to: nil) == nil)
    }

    @Test(arguments: [
        (["font", "pageTitle", "weight"], "bld"),
        (["font", "sectionHeader", "style"], "titel3"),
        (["font", "noteEditor", "design"], "mono"),
        (["font", "pageTitle", "sise"], "34"),
    ])
    func aBadFontNameIsAConfigError(path: [String], value: String) throws {
        let error = try #require(try configError(setting: path, to: value))
        #expect(error.file == "tokens.json")
        #expect(error.path == path.joined(separator: "."))
    }

    @Test func aFontSizeMustBePositive() throws {
        let error = try #require(try configError(setting: ["font", "pageTitle", "size"], to: -34))
        #expect(error.path == "font.pageTitle.size")
    }

    @Test(arguments: [
        (["color", "screenBackground", "system"], "systemGroupBackground"),
        (["color", "task", "light"], "#007AFG"),
        (["color", "task", "dark"], "0A84F"),
    ])
    func aBadColorValueIsAConfigError(path: [String], value: String) throws {
        let error = try #require(try configError(setting: path, to: value))
        #expect(error.path == path.joined(separator: "."))
    }

    /// A color needs a hex for the light theme or a system color: not neither, not both.
    @Test func aColorIsEitherSystemOrHex() throws {
        let missing = try #require(try configError(setting: ["color", "task", "light"], to: nil))
        #expect(missing.path == "color.task")
        let both = try #require(try configError(setting: ["color", "primaryText", "light"], to: "#000000"))
        #expect(both.path == "color.primaryText")
    }

    /// The colors a settings section offers are color tokens: a misspelt one is a config error, not a missing row.
    @Test func anEditableColorIsAColorToken() throws {
        let error = try #require(try configError(setting: ["editableColors", "habits"], to: ["habbit"]))
        #expect(error.path == "editableColors.habits.[0]")
    }

    /// Every color a settings section offers has its row title.
    @Test func everyEditableColorHasATitle() {
        for group in ColorSettingsGroup.allCases {
            for token in TestConfig.tokens.editableColors[group] {
                #expect(Bundle.main.localizedString(forKey: "color." + token.rawValue, value: "∅", table: nil) != "∅", "\(token)")
            }
        }
    }

    /// The message lists what the name can be.
    @Test func theMessageNamesTheKnownValues() throws {
        let error = try #require(try configError(setting: ["font", "pageTitle", "weight"], to: "bld"))
        #expect(error.message.contains("\"bld\""))
        #expect(error.message.contains("\"semibold\""))
    }

    /// tokens.json with one value set (`nil` removes the key), decoded the way the app loads it.
    private func configError(setting path: [String], to value: Any?) throws -> ConfigError? {
        let url = TestPaths.configFolder.appendingPathComponent("tokens.json")
        let tokens = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let json = try JSONSerialization.data(withJSONObject: path.isEmpty ? tokens : setting(path[...], to: value, in: tokens))
        do {
            _ = try ConfigLoader.decode(DesignTokens.self, from: json, file: "tokens.json")
            return nil
        } catch let error as ConfigError {
            return error
        }
    }

    private func setting(_ path: ArraySlice<String>, to value: Any?, in object: [String: Any]) -> [String: Any] {
        guard let key = path.first else { return object }
        var object = object
        if path.count == 1 {
            object[key] = value
        } else {
            object[key] = setting(path.dropFirst(), to: value, in: object[key] as? [String: Any] ?? [:])
        }
        return object
    }
}
