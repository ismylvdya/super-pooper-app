import Foundation

/// A date found in a typed name: where its words stand and the date and time they mean.
struct DetectedDate: Equatable, Sendable {
    /// The words of the date and of the time, in text order; a date and a time with only spaces between are one range.
    let ranges: [Range<String.Index>]
    let due: TaskDue
}
