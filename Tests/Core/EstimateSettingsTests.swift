import Testing
@testable import SuperPooperApp

/// The estimates' minutes come from the settings; the last keeps its word, an unchanged option its label.
struct EstimateSettingsTests {
    private let rules = TestConfig.rules

    @Test func theMinutesReplaceTheOptions() {
        let options = rules.withEstimates([5, 15, 45, 300]).timeEstimates
        #expect(options.map(\.minutes) == [5, 15, 45, 300])
        #expect(options[1].label == rules.timeEstimates[1].label)
        #expect(options[3].label == rules.timeEstimates[3].label)
    }

    @Test func theSameMinutesTwiceAreOneOption() {
        #expect(rules.withEstimates([15, 15, 60, 240]).timeEstimates.map(\.minutes) == [15, 60, 240])
    }

    /// A task with minutes no option has any more keeps them in its picker.
    @Test func aValueNoOptionHasStaysOffered() {
        #expect(rules.estimateOptions(including: 7).map(\.minutes) == [2, 15, 60, 240, 7])
    }
}
