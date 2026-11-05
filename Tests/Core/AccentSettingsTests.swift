import Testing
import UIKit
@testable import SuperPooperApp

/// The accent the user picked goes only to the kinds of elements that are switched on.
struct AccentSettingsTests {
    private let limits = TestConfig.rules.limits

    private func tokens(_ categories: [String]) throws -> DesignTokens {
        var settings = TestConfig.defaults
        settings.colors["accentPick"] = "#FF0000"
        settings.accent.categories = categories
        return TestConfig.tokens.applying(settings, limits: limits)
    }

    @Test func aCategoryThatIsOnTakesThePickedColor() throws {
        let shown = try tokens(["selects", "switches"])
        #expect(shown.uiColor(.accentSelect).hexString == "#FF0000")
        #expect(shown.uiColor(.accentSwitch).hexString == "#FF0000")
    }

    @Test func aCategoryThatIsOffKeepsItsOwnColor() throws {
        let shown = try tokens(["selects"])
        #expect(shown.uiColor(.accentToolbar).hexString != "#FF0000")
        #expect(shown.uiColor(.accentSwitch).cgColor == UIColor.systemGreen.cgColor)
    }

    @Test func anUnknownCategoryIsIgnored() throws {
        #expect(try tokens(["gone"]).uiColor(.accentSelect).hexString != "#FF0000")
    }

    @Test func byDefaultSwitchesAreTheSystemGreen() throws {
        let shown = TestConfig.tokens.applying(TestConfig.defaults, limits: limits)
        #expect(shown.uiColor(.accentSwitch).cgColor == UIColor.systemGreen.cgColor)
    }
}
