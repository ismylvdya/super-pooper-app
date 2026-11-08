import Testing
import UIKit
@testable import SuperPooperApp

/// The accent color the user picked goes to the tab bar alone, and only while its switch is on.
struct AccentSettingsTests {
    private func tokens(tabBar: Bool) -> DesignTokens {
        var settings = TestConfig.defaults
        settings.colors["tabBarPick"] = "#FF0000"
        settings.accent.tabBar = tabBar
        return TestConfig.tokens.applying(settings, limits: TestConfig.rules.limits)
    }

    @Test func switchedOnTheTabBarTakesThePickedColor() {
        #expect(tokens(tabBar: true).uiColor(.tabBar).hexString == "#FF0000")
    }

    @Test func switchedOffTheTabBarKeepsTheTextColor() {
        #expect(tokens(tabBar: false).uiColor(.tabBar).hexString != "#FF0000")
    }

    @Test func nothingElseTakesIt() {
        #expect(tokens(tabBar: true).uiColor(.accent).hexString != "#FF0000")
    }

    @Test func switchesAreTheSystemGreen() {
        #expect(tokens(tabBar: true).uiColor(.switchOn).cgColor == UIColor.systemGreen.cgColor)
    }

    @Test func byDefaultTheSwitchIsOff() {
        #expect(!TestConfig.defaults.accent.tabBar)
    }
}

/// The alarm's Snooze button keeps the bundled symbol until another is picked.
@Suite("Snooze icon")
struct SnoozeIconTests {
    @Test func byDefaultTheBundledSymbol() {
        #expect(TestConfig.defaults.notifications.alarmSnoozeIcon.isEmpty)
    }

    @Test func theOfferedSymbolsAreNotTheBundledOne() {
        #expect(!TestConfig.rules.notifications.snoozeIcons.isEmpty)
        #expect(!TestConfig.rules.notifications.snoozeIcons.contains("zzz"))
    }
}
