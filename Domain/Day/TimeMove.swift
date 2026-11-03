import Foundation

/// A block of a timed task or habit moved on today's timeline (dragged, or snoozed from its notification): its time `slot`
/// (as the note has it) stands at `time` today, or in the pool (`time` nil: no time and no notification today). Kept for
/// the logical day only (`DayState`); the note keeps its times. `placed`: a block the note does not have at all, a habit
/// with no reminder times dragged from the pool onto the timeline; `slot` is the time it was first dropped at, its name
/// for today, and it rings like any block, that day only.
struct TimeMove: Codable, Hashable, Sendable {
    let task: String
    let slot: LocalTime
    let time: LocalTime?
    var placed: Bool? = nil

    var isPlaced: Bool { placed == true }
}
