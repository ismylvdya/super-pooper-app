import Testing
@testable import SuperPooperApp

struct EstimateSettingsTests {
    private let rules = TestConfig.rules

    @Test func onlyTheFourPresetsAreStored() {
        let presets = [2, 15, 60, 240]
        #expect(rules.timeEstimates.map(\.minutes) == presets)
        for minutes in presets {
            #expect(rules.estimateMinutes(minutes) == minutes)
        }
        for minutes in [nil, 0, 5, 90] {
            #expect(rules.estimateMinutes(minutes) == 15)
        }
    }
}
