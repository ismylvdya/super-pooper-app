import Testing
@testable import SuperPooperApp

/// The Pleasant and Need energy chips stand for the one feel property of a task.
struct FeelChipTests {
    @Test func aFeelChipTurnsItsFeelOnAndOff() {
        #expect(FeelChip.toggling(.pleasant, current: .neutral) == .pleasant)
        #expect(FeelChip.toggling(.pleasant, current: .pleasant) == .neutral)
        #expect(FeelChip.toggling(.needEnergy, current: .pleasant) == .needEnergy)
        #expect(FeelChip.toggling(.needEnergy, current: .needEnergy) == .neutral)
    }
}
