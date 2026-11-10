import Foundation
import Testing
@testable import SuperPooperApp

/// A second finger up or down while the "+" is dragged picks the new task's estimate.
@Suite("New item estimate")
struct NewItemEstimateTests {
    private let options = [2, 15, 60, 240]

    @Test func itStartsAtTheDefaultAndStepsByTheDistance() {
        #expect(NewItemEstimate.minutes(options: options, default: 15, rise: 10, step: 60) == 15)
        #expect(NewItemEstimate.minutes(options: options, default: 15, rise: 65, step: 60) == 60)
        #expect(NewItemEstimate.minutes(options: options, default: 15, rise: 130, step: 60) == 240)
        #expect(NewItemEstimate.minutes(options: options, default: 15, rise: -70, step: 60) == 2)
    }

    @Test func itStaysWithinTheOptions() {
        #expect(NewItemEstimate.minutes(options: options, default: 15, rise: 1000, step: 60) == 240)
        #expect(NewItemEstimate.minutes(options: options, default: 15, rise: -1000, step: 60) == 2)
    }
}
