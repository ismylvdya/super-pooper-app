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
    /// subtask stays with its parent. A worm's members stand together, with their subtasks, after the first of them in the
    /// shown order and in its section. Own sections without tasks are left out; the default ones always show.
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
        if !sections.worms.isEmpty { items = keepingWormsTogether(items, order: sections.order.map(\.id), worms: sections.worms) }
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
    private struct Block {
        var section: String
        let items: [DayItem]
        var root: DayItem { items[0] }
    }

    private static func keepingWormsTogether(_ items: [String: [DayItem]], order: [String],
                                             worms: [DayWorm]) -> [String: [DayItem]] {
        var blocks: [Block] = []
        for section in order + items.keys.filter({ !order.contains($0) }).sorted() {
            for item in items[section] ?? [] {
                if item.depth > 0, let last = blocks.last, last.section == section {
                    blocks[blocks.count - 1] = Block(section: section, items: last.items + [item])
                } else {
                    blocks.append(Block(section: section, items: [item]))
                }
            }
        }
        for worm in worms {
            let members = blocks.indices.filter { blocks[$0].root.depth == 0 && worm.members.containsNoteName(blocks[$0].root.id) }
            guard let first = members.first, members.count > 1 else { continue }
            let following = members.dropFirst().map { Block(section: blocks[first].section, items: blocks[$0].items) }
            for index in members.dropFirst().reversed() { blocks.remove(at: index) }
            blocks.insert(contentsOf: following, at: first + 1)
        }
        var result: [String: [DayItem]] = [:]
        for block in blocks { result[block.section, default: []] += block.items }
        return result
    }

    /// The sections while a task is dragged over the pool: the task in `section` (nil: where it stands), each section's
    /// tasks in the order the finger makes.
    static func hovering(_ sections: [PoolSectionContent], order: [String], dragged: DayItem,
                         into section: String?) -> [PoolSectionContent] {
        hovering(sections, order: order, dragged: [dragged], into: section)
    }

    /// The same for a worm dragged whole: `dragged` its members, the grabbed one first.
    static func hovering(_ sections: [PoolSectionContent], order: [String], dragged: [DayItem],
                         into section: String?) -> [PoolSectionContent] {
        guard let grabbed = dragged.first else { return sections }
        let place = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let target = section ?? sections.first { $0.items.contains { $0.id == grabbed.id } }?.id
        let ids = Set(dragged.map(\.id))
        return sections.map { content in
            var items = content.items.filter { !ids.contains($0.id) }
            if content.id == target { items += dragged }
            items.sort { (place[$0.id] ?? .max) < (place[$1.id] ?? .max) }
            return PoolSectionContent(id: content.id, title: content.title, isCustom: content.isCustom, items: items)
        }
    }

    /// The sections in the order of `ids` (those not named keep their places after them).
    static func reordered(_ sections: [PoolSectionContent], by ids: [String]) -> [PoolSectionContent] {
        ids.compactMap { id in sections.first { $0.id == id } } + sections.filter { !ids.contains($0.id) }
    }
}
