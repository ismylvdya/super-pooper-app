import Foundation

/// A block of a timed task or habit moved on today's timeline (dragged, or snoozed from its notification): its time `slot`
/// (as the note has it) stands at `time` today, or in the pool (`time` nil: no time and no notification today). Kept for
/// the logical day only (`DayState`); the note keeps its times.
struct TimeMove: Codable, Hashable, Sendable {
    let task: String
    let slot: LocalTime
    let time: LocalTime?
}
