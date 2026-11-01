import Foundation

/// A habit's block dragged on today's timeline: its reminder time `slot` (as the note has it) stands at `time` today, or
/// in the pool (`time` nil: no time and no notification today). Kept for the logical day only (`DayState`); the note
/// keeps its times.
struct HabitTimeMove: Codable, Hashable, Sendable {
    let habit: String
    let slot: LocalTime
    let time: LocalTime?
}
