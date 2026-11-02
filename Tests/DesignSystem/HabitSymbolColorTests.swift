import SwiftUI
import Testing
import UIKit
@testable import SuperPooperApp

/// The habit symbol before a repeatable task in search is in the habits' color (.27911), not in its marks' (the name's)
/// color; a habit's own color still wins.
struct HabitSymbolColorTests {
    private let tokens = TestConfig.tokens

    @Test func aRepeatableTasksSymbolIsInTheHabitsColor() {
        let repeatable = makeHabit("Pay rent") { $0.habit.repeatable = true }
        #expect(hex(tokens.habitSymbolColor(repeatable)) == hex(tokens.color(.habit)))
        #expect(hex(tokens.habitMarkColor(repeatable)) == hex(tokens.color(.primaryText)), "its marks stay in its name's color")
    }

    @Test func aHabitsOwnColorWins() {
        let habit = makeHabit("Run") { $0.habit.color = "#FF0000" }
        #expect(hex(tokens.habitSymbolColor(habit)) == "#FF0000")
        #expect(hex(tokens.habitSymbolColor(habit)) != hex(tokens.color(.habit)))
    }

    /// The color as it is drawn in light mode.
    private func hex(_ color: Color) -> String {
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).hexString
    }
}
