import Foundation

/// The estimate a second finger sets while the "+" is dragged: from the default one, a step longer for every
/// `step` it moved the longer way from where it touched (`gestures.estimateLongerDown`), a step shorter for every `step`
/// the other way, within the estimates offered.
enum NewItemEstimate {
    /// `rise`: how far up the second finger is from where it touched (down is negative); `longerDown`: down is longer.
    static func minutes(options: [Int], default value: Int, rise: Double, step: Double, longerDown: Bool = false) -> Int? {
        let sorted = options.sorted()
        guard !sorted.isEmpty, step > 0 else { return nil }
        let start = sorted.firstIndex { $0 >= value } ?? sorted.count - 1
        let steps = Int(((longerDown ? -rise : rise) / step).rounded(.towardZero))
        return sorted[min(max(start + steps, 0), sorted.count - 1)]
    }
}
