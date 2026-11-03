import Foundation

/// One rule for every pull past an edge (a list pulled down, the first page of Tasks pulled sideways): past `threshold`
/// it arms once (the moment to feel), under half of it it disarms again, and letting go while armed runs the action.
struct PullArming: Equatable, Sendable {
    private(set) var isArmed = false

    /// The pull is now `pull` long; true when it has just armed.
    mutating func update(pull: Double, threshold: Double) -> Bool {
        if pull >= threshold, !isArmed {
            isArmed = true
            return true
        }
        if pull < threshold / 2 { isArmed = false }
        return false
    }

    /// The finger lifts: true when the action runs.
    mutating func release() -> Bool {
        defer { isArmed = false }
        return isArmed
    }

    /// How far content moves for a finger `distance` past its edge, the way a scroll view resists there: almost all of it
    /// at first, less and less towards `dimension` (`resistance` is the scroll view's own factor).
    static func stretch(_ distance: Double, dimension: Double, resistance: Double) -> Double {
        guard distance > 0, dimension > 0 else { return 0 }
        return (1 - 1 / (distance * resistance / dimension + 1)) * dimension
    }
}
