import Foundation

/// The estimate a second finger sets while the "+" is dragged: from the default one, a step longer for every
/// `step` it moved up from where it touched, a step shorter for every `step` down, within the estimates offered.
enum NewItemEstimate {
    /// `rise`: how far up the second finger is from where it touched (down is negative).
    static func minutes(options: [Int], default value: Int, rise: Double, step: Double) -> Int? {
        let sorted = options.sorted()
        guard !sorted.isEmpty, step > 0 else { return nil }
        let start = sorted.firstIndex { $0 >= value } ?? sorted.count - 1
        let steps = Int((rise / step).rounded(.towardZero))
        return sorted[min(max(start + steps, 0), sorted.count - 1)]
    }
}
