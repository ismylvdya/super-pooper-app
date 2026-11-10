import Foundation

extension RulesConfig {
    /// Ranges of the number controls on settings and note pages.
    struct Limits: Codable, Hashable, Sendable {
        struct Range: Codable, Hashable, Sendable {
            let min: Double
            let max: Double
            /// The slider step, when it has one.
            var step: Double?

            var closed: ClosedRange<Double> { min...max }

            /// The value kept within the range.
            func clamped(_ value: Double) -> Double { Swift.min(Swift.max(value, min), max) }

            /// The nearest step (unchanged without one).
            func snapped(_ value: Double) -> Double {
                guard let step, step > 0 else { return value }
                return (value / step).rounded() * step
            }
            var ints: ClosedRange<Int> { Int(min)...Int(max) }
        }

        let poolVisibleCount: Range
        let hoursBefore: Range
        let bellSize: Range
        let bellOpacity: Range
        let fontSize: Range
        let pastOpacity: Range
        /// The share of a plate a started task's fill reaches.
        let startedFillLength: Range
        /// How big a started task's circle can be set, as a share between its smallest and largest.
        let startedCircleSize: Range
        /// The ring of a habit's day not done or done partly.
        let ringOpacity: Range
        /// How solid the outline of a task picked in Select mode is.
        let selectionOutlineOpacity: Range
        let recurrenceInterval: Range
        /// "Each" day number of a monthly repeat.
        let monthDay: Range
    }
}
