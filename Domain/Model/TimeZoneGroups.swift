import Foundation

/// The zones as a list goes through them: by their offset from UTC now, those that keep the same clock together. Zones with one
/// offset today may part at the next change of clocks (Belgrade and Lagos are both +1 in winter), so each keeps a row of its
/// own; a pick is true all year that way. The offsets and changes are the system's own zone data for the date asked about, which
/// iOS keeps up to date: a zone moves to its summer offset by itself on the day it does.
struct TimeZoneGroup: Equatable, Sendable {
    let offsetSeconds: Int
    /// The group's zones, the most known first; the first is the one a pick of the group takes.
    let identifiers: [String]
}

enum TimeZoneGroups {
    /// `known`: every zone; `priority`: the zones to come first in their groups, in order (`rules.json` → `timeZones`).
    static func groups(of known: [String], priority: [String], at date: Date) -> [TimeZoneGroup] {
        struct Key: Hashable {
            let offset: Int
            let nextChange: Date?
        }
        var byClock: [Key: [String]] = [:]
        for identifier in known {
            guard let zone = TimeZone(identifier: identifier) else { continue }
            byClock[Key(offset: zone.secondsFromGMT(for: date), nextChange: zone.nextDaylightSavingTimeTransition(after: date)), default: []].append(identifier)
        }
        let rank = Dictionary(priority.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        let ordered = { (a: String, b: String) in (rank[a] ?? Int.max, a) < (rank[b] ?? Int.max, b) }
        return byClock.map { key, identifiers in
            (key, TimeZoneGroup(offsetSeconds: key.offset, identifiers: identifiers.sorted(by: ordered)))
        }
        .sorted { lhs, rhs in
            let first = lhs.1.identifiers[0], second = rhs.1.identifiers[0]
            return lhs.1.offsetSeconds == rhs.1.offsetSeconds ? ordered(first, second) : lhs.1.offsetSeconds < rhs.1.offsetSeconds
        }
        .map(\.1)
    }

    /// Zones alone, by offset, for a search: the one looked for is what a pick takes.
    static func zones(_ identifiers: [String], priority: [String], at date: Date) -> [String] {
        groups(of: identifiers, priority: priority, at: date).flatMap(\.identifiers)
    }
}
