import Foundation

/// How today's pool stands in the store's file: its sections with their lines in order, and what was kept out of today.
/// The app writes it there and reads it back, so a change made elsewhere (by hand, on another device) comes to the app.
struct DayLook: Codable, Equatable, Sendable {
    struct Section: Codable, Equatable, Sendable {
        let title: String
        let names: [String]
    }

    var sections: [Section] = []
    /// Habits taken out of today: their lines wait for a later day.
    var skipped: [String] = []
    /// The times habits' lines have today: moved by hand in the file, they move on today's timeline.
    var times: [String: LocalTime]? = nil

    /// Every line in order, the pool's only.
    var poolOrder: [String] { sections.flatMap(\.names) }

    /// Another order, section or title of a line both looks have. A line only one has says nothing: the app itself adds
    /// and removes lines with every write, between two looks it writes.
    func differs(from other: DayLook) -> Bool {
        let names = Set(places.map(\.name)).intersection(other.places.map(\.name))
        let common = { (look: DayLook) in look.places.filter { names.contains($0.name) } }
        return common(self) != common(other) || !movedTimes(since: other).isEmpty
    }

    /// The lines' times that are not what `other` had for them.
    func movedTimes(since other: DayLook?) -> [String: LocalTime] {
        guard let other else { return [:] }
        return (times ?? [:]).filter { name, time in (other.times ?? [:])[name].map { $0 != time } ?? false }
    }

    private struct Place: Equatable {
        let name: NoteName
        let section: String?
    }

    private var places: [Place] {
        sections.flatMap { section in section.names.map { Place(name: $0.noteName, section: section.title) } }
            + skipped.map { Place(name: $0.noteName, section: nil) }.sorted { String(describing: $0.name) < String(describing: $1.name) }
    }
}

extension DaySections {
    /// The day's sections as `look` has them: a section goes by its title as shown (`title`), a title not known yet is an
    /// own section under a new id; sections the look does not name (they are empty) stay behind. Each line stands in its
    /// section.
    func applying(_ look: DayLook, title: (DaySection) -> String, makeID: () -> String) -> DaySections {
        var result = self
        var named: [DaySection] = []
        for section in look.sections {
            let known = order.first { title($0) == section.title }
            let shown = known ?? DaySection(id: makeID(), title: section.title, isCustom: true)
            named.append(shown)
            for name in section.names {
                result.membership = result.membership.filter { !$0.key.isSameNoteName(as: name) }
                result.membership[name] = shown.id
            }
        }
        result.order = named + order.filter { old in !named.contains { $0.id == old.id } }
        return result
    }
}
