import Foundation

/// What the store's file says about today's habits: what was kept out of today, and the times their lines have. The app
/// writes it there and reads it back, so a change made elsewhere (by hand, on another device) comes to the app. Which
/// section a task stands in is its own line's (`TaskItem.poolSection`); the pool's order is the app's.
struct DayLook: Codable, Equatable, Sendable {
    /// Habits taken out of today: their lines wait for a later day.
    var skipped: [String] = []
    /// The times habits' lines have today: moved by hand in the file, they move on today's timeline.
    var times: [String: LocalTime]? = nil
    /// The habits whose lines today have no time.
    var untimed: [String] = []

    /// Another set of habits kept out of today.
    func differs(from other: DayLook) -> Bool {
        Set(skipped.map(\.noteName)) != Set(other.skipped.map(\.noteName))
    }
}
