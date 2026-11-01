import Foundation

/// When the plate shows and how its level is chosen (`rules.json` → `signingPlate`), in days before the end.
struct SigningPlateRules: Codable, Hashable, Sendable {
    /// The plate shows from this many days before the end (more left: no plate).
    let showWithinDays: Double
    /// Less than this many days left: yellow.
    let soonWithinDays: Double
    /// Less than this many days left: red, counted in hours.
    let urgentWithinDays: Double
}
