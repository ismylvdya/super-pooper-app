import ListEngineChumbulev

/// The pool's sections and landing positions, shared by its different presentations.
struct DayPoolRows {
    let sections: [ListSection<DayItem>]

    init(plan: DayPlan, daySections: DaySections, definitions: [PoolSectionDefinition], includesEmpty: Bool = false) {
        if includesEmpty {
            let shown = Dictionary(uniqueKeysWithValues: plan.sections.map { ($0.id, $0) })
            let titles = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0.title) })
            sections = daySections.order.map { section in
                Self.row(shown[section.id] ?? PoolSectionContent(id: section.id, title: section.title ?? titles[section.id] ?? section.id,
                                                                isCustom: section.title != nil, items: []))
            }
        } else if plan.sections.isEmpty {
            // An empty pool still offers a landing at the default section.
            sections = [ListSection(id: definitions.restID, title: "", items: plan.pool)]
        } else {
            sections = plan.sections.map(Self.row)
        }
    }

    private static func row(_ section: PoolSectionContent) -> ListSection<DayItem> {
        ListSection(id: section.id, title: section.isCustom ? section.title : (section.hasHeader ? L10n.string(section.title) : ""),
                    items: section.items)
    }

    func parent(at drop: ListDrop) -> String? {
        guard let rows = sections.first(where: { $0.id == drop.sectionID })?.items,
              let index = drop.parentRow, rows.indices.contains(index) else { return nil }
        return rows[index].id
    }

    func order(inserting names: [String], at drop: ListDrop) -> [String] {
        let index = sections.firstIndex { $0.id == drop.sectionID } ?? sections.endIndex
        let before = sections.prefix(index).flatMap(\.items).map(\.id).filter { !names.contains($0) }
        let after = sections.dropFirst(index + 1).flatMap(\.items).map(\.id).filter { !names.contains($0) }
        var rows = sections.indices.contains(index) ? sections[index].items.map(\.id).filter { !names.contains($0) } : []
        rows.insert(contentsOf: names, at: min(drop.row, rows.count))
        return before + rows + after
    }

    func move(_ newer: [ListSection<DayItem>], model: AppModel, day: LocalDate, savesOrder: Bool) {
        let previous = Dictionary(sections.flatMap { section in section.items.map { ($0.id, section.id) } },
                                  uniquingKeysWith: { first, _ in first })
        let moved = newer.filter { section in sections.contains { $0.id == section.id } }
        let groups = moved.flatMap { section in
            section.items.filter { previous[$0.id] != section.id }.map { ($0.id, section.id) }
        }
        let order = savesOrder ? moved.flatMap(\.items).map(\.id) : nil
        Task { await model.relocatePoolRows(groups, order: order, on: day) }
    }
}
