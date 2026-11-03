import Foundation

/// One section of a day's pool with its tasks.
struct PoolSectionContent: Identifiable, Hashable, Sendable {
    let id: String
    /// A text key (a default section) or the user's own title (`isCustom`).
    let title: String
    let isCustom: Bool
    let items: [DayItem]
}

/// The pool split into the day's sections.
enum PoolArrangement {
    /// Sections in their order; each holds its tasks in the pool's sort and manual order. A task moved into a section
    /// that day stands there; the others go by their routine (`time_of_day`) or to the section that catches the rest. A
    /// subtask stays with its parent. Own sections without tasks are left out; the default ones always show.
    static func arrange(_ pool: [DayItem], sections: DaySections, definitions: [PoolSectionDefinition]) -> [PoolSectionContent] {
        guard !definitions.isEmpty else { return [] }
        let known = Set(sections.order.map(\.id))
        let shown = { (id: String?) in id.flatMap { known.contains($0) ? $0 : nil } }
        let rest = shown(definitions.restID) ?? sections.order.first?.id ?? definitions.restID
        var items: [String: [DayItem]] = [:]
        var rootSection = rest
        for item in pool {
            if item.depth == 0 {
                rootSection = shown(sections.section(of: item.id)) ?? shown(definitions.id(for: item.task.habit.timeOfDay)) ?? rest
            }
            items[rootSection, default: []].append(item)
        }
        let titles = Dictionary(definitions.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
        return sections.order.compactMap { section in
            let members = items[section.id] ?? []
            guard !section.isCustom || !members.isEmpty else { return nil }
            return PoolSectionContent(id: section.id, title: section.title ?? titles[section.id] ?? section.id,
                                      isCustom: section.isCustom, items: members)
        }
    }
}

extension PoolArrangement {
    /// The sections while a task is dragged over the pool: the task in `section` (nil: where it stands), each section's
    /// tasks in the order the finger makes.
    static func hovering(_ sections: [PoolSectionContent], order: [String], dragged: DayItem,
                         into section: String?) -> [PoolSectionContent] {
        let place = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let target = section ?? sections.first { $0.items.contains { $0.id == dragged.id } }?.id
        return sections.map { content in
            var items = content.items.filter { $0.id != dragged.id }
            if content.id == target { items.append(dragged) }
            items.sort { (place[$0.id] ?? .max) < (place[$1.id] ?? .max) }
            return PoolSectionContent(id: content.id, title: content.title, isCustom: content.isCustom, items: items)
        }
    }

    /// The sections in the order of `ids` (those not named keep their places after them).
    static func reordered(_ sections: [PoolSectionContent], by ids: [String]) -> [PoolSectionContent] {
        ids.compactMap { id in sections.first { $0.id == id } } + sections.filter { !ids.contains($0.id) }
    }
}
