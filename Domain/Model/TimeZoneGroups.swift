import Foundation

/// The zones as a list goes through them: one row for each offset from UTC now. The offsets are the system's own zone data for the
/// date asked about, which iOS keeps up to date: a zone moves to its summer offset by itself on the day it does. A row's pick is its
/// first zone; a zone of another clock with that offset now (Lagos beside Belgrade) is found by searching for it.
struct TimeZoneGroup: Equatable, Sendable {
    let offsetSeconds: Int
    /// The group's zones, the most known first; the first is the one a pick of the group takes.
    let identifiers: [String]
}

enum TimeZoneGroups {
    /// `known`: every zone; `priority`: the zones to come first in their groups, in order (`rules.json` → `timeZones`).
    static func groups(of known: [String], priority: [String], at date: Date) -> [TimeZoneGroup] {
        var byOffset: [Int: [String]] = [:]
        for identifier in known {
            guard let zone = TimeZone(identifier: identifier) else { continue }
            byOffset[zone.secondsFromGMT(for: date), default: []].append(identifier)
        }
        let rank = Dictionary(priority.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        let ordered = { (a: String, b: String) in (rank[a] ?? Int.max, a) < (rank[b] ?? Int.max, b) }
        return byOffset.keys.sorted().map { offset in
            TimeZoneGroup(offsetSeconds: offset, identifiers: (byOffset[offset] ?? []).sorted(by: ordered))
        }
    }

    /// Zones alone, by offset, for a search: the one looked for is what a pick takes.
    static func zones(_ identifiers: [String], priority: [String], at date: Date) -> [String] {
        groups(of: identifiers, priority: priority, at: date).flatMap(\.identifiers)
    }
}
