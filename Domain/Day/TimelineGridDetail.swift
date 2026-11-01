import Foundation

/// The finer marks a zoomed-in timeline shows: ":15", ":30" and ":45" next to every hour once the visible height holds
/// about five hours, and a line every five minutes once it holds about two. Each fades in smoothly while the pinch goes
/// through its range (`rules.json` → `timeline.detail`).
struct TimelineGridDetail: Equatable, Sendable {
    /// When a kind of mark shows: not at all from `hiddenAboveHours` visible hours up, fully at `fullAtHours` and below.
    struct Fade: Codable, Hashable, Sendable {
        let hiddenAboveHours: Double
        let fullAtHours: Double

        func opacity(visibleHours: Double) -> Double {
            guard hiddenAboveHours > fullAtHours else { return visibleHours <= fullAtHours ? 1 : 0 }
            return min(max((hiddenAboveHours - visibleHours) / (hiddenAboveHours - fullAtHours), 0), 1)
        }
    }

    struct Rules: Codable, Hashable, Sendable {
        let quarters: Fade
        let fiveMinutes: Fade
    }

    /// How far each kind has faded in, 0…1.
    let quarters: Double
    let fiveMinutes: Double

    static let none = TimelineGridDetail(quarters: 0, fiveMinutes: 0)

    /// The marks of a timeline whose visible height holds `visibleHours` hours.
    init(visibleHours: Double, rules: Rules) {
        quarters = rules.quarters.opacity(visibleHours: visibleHours)
        fiveMinutes = rules.fiveMinutes.opacity(visibleHours: visibleHours)
    }

    init(quarters: Double, fiveMinutes: Double) {
        self.quarters = quarters
        self.fiveMinutes = fiveMinutes
    }

    /// The minutes past the hour that get a mark of their own: every `step` minutes but the hour itself.
    static func minutes(every step: Int) -> [Int] {
        guard step > 0 else { return [] }
        return Array(stride(from: step, to: 60, by: step))
    }
}
