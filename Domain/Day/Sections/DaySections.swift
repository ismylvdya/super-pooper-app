import Foundation

/// A section of one day's pool: one of the defaults (its title from the definition) or the user's own.
struct DaySection: Codable, Hashable, Sendable {
    let id: String
    /// The user's title of an own section; nil = the definition's text key.
    var title: String?
    var isCustom: Bool
}

/// Tasks the user joined on one plate for a day (purely visual: nothing is written to the notes).
struct DayWorm: Codable, Hashable, Sendable {
    let id: String
    var members: [String]
}

/// How one day's pool is split: its sections in their order, the tasks moved into a section that day, and its worms.
/// App-only state, kept per day (`DaySectionStorage`); a day without a snapshot gets the default sections.
struct DaySections: Codable, Equatable, Sendable {
    let day: LocalDate
    var order: [DaySection]
    /// Note name → section id; only the tasks moved there, the rest go by their routine.
    var membership: [String: String]
    var worms: [DayWorm] = []

    init(day: LocalDate, order: [DaySection], membership: [String: String] = [:], worms: [DayWorm] = []) {
        self.day = day
        self.order = order
        self.membership = membership
        self.worms = worms
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(LocalDate.self, forKey: .day)
        order = try container.decode([DaySection].self, forKey: .order)
        membership = try container.decodeIfPresent([String: String].self, forKey: .membership) ?? [:]
        worms = try container.decodeIfPresent([DayWorm].self, forKey: .worms) ?? []
    }

    static func defaults(on day: LocalDate, definitions: [PoolSectionDefinition]) -> DaySections {
        DaySections(day: day, order: definitions.map { DaySection(id: $0.id, title: nil, isCustom: false) })
    }

    /// The section a task was moved into that day, if any.
    func section(of name: String) -> String? {
        membership[name] ?? membership.first { $0.key.isSameNoteName(as: name) }?.value
    }

    func renaming(from old: String, to new: String) -> DaySections {
        var result = self
        result.membership = Dictionary(membership.map { ($0.key.isSameNoteName(as: old) ? new : $0.key, $0.value) },
                                       uniquingKeysWith: { _, last in last })
        result.worms = worms.map { DayWorm(id: $0.id, members: NameReferences.renaming($0.members, from: old, to: new)) }
        return result
    }

    /// The notes gone (deleted): no section keeps them, and a worm left with one member is no worm.
    func removing(_ names: [String]) -> DaySections {
        var result = self
        let gone = { (name: String) in names.containsNoteName(name) }
        result.membership = membership.filter { !gone($0.key) }
        result.worms = worms.map { DayWorm(id: $0.id, members: $0.members.filter { !gone($0) }) }.filter { $0.members.count > 1 }
        return result
    }

    /// The worm a task is a member of that day.
    func worm(of name: String) -> DayWorm? {
        worms.first { $0.members.containsNoteName(name) }
    }

    /// The tasks on one plate: a worm any of them was in takes the others along (and keeps its id, else `id`).
    func worming(_ names: [String], id: String) -> DaySections {
        let touched = worms.filter { worm in names.contains { worm.members.containsNoteName($0) } }
        var members = touched.flatMap(\.members)
        for name in names where !members.containsNoteName(name) { members.append(name) }
        guard members.count > 1 else { return self }
        var result = self
        result.worms = worms.filter { !touched.contains($0) } + [DayWorm(id: touched.first?.id ?? id, members: members)]
        return result
    }

    /// The tasks off their worms; a worm left with one member is no worm.
    func unworming(_ names: [String]) -> DaySections {
        var result = self
        result.worms = worms.map { DayWorm(id: $0.id, members: $0.members.filter { !names.containsNoteName($0) }) }
            .filter { $0.members.count > 1 }
        return result
    }
}
