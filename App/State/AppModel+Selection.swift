import Foundation

/// The pool's Select mode: what the selected tasks offer (`BatchAvailability`) and the action on all of them.
extension AppModel {
    /// The selected tasks as the pool of `day` shows them, in its order.
    func poolItems(named names: Set<String>, on day: LocalDate) -> [DayItem] {
        plan(at: clock.now, dayOffset: context().today.days(until: day)).pool.filter { names.contains($0.id) }
    }

    /// The selection bar's buttons and its "…" menu for the selected tasks, each as `actions.json` orders them. An action
    /// that would need its confirmation is left out: Select acts at once and the banner offers Undo.
    func selectionEntries(for names: Set<String>, on day: LocalDate) -> (frequent: [ActionDefinition], more: [ActionDefinition]) {
        let availability = BatchAvailability(single: ActionAvailability(capabilities: parts.capabilities, isToday: day == context().today,
                                                                        canSelect: true, worms: sections(on: day).worms))
        let entries = availability.entries(config.actions.menus[.selection], for: poolItems(named: names, on: day))
        let definitions = { (ids: [ActionID]) in ids.map(self.config.actions.definition).filter { !self.needsConfirmation($0) } }
        return (definitions(entries.frequent), definitions(entries.more))
    }

    /// The action of the selection bar on the selected tasks of `day`'s pool (New section has its own title: `newSection`).
    func perform(_ action: ActionDefinition, onSelected names: Set<String>, on day: LocalDate) async {
        let items = poolItems(named: names, on: day)
        switch action.id {
        case .worm: worm(BatchAvailability.wormable(items).map(\.id), on: day)
        case .unworm: unworm(items.map(\.id), on: day)
        default: await performOfferingUndo(action, on: items.map(\.id), day: day == context().today ? nil : day)
        }
    }

    @discardableResult
    func newSection(titled title: String, withSelected names: Set<String>, on day: LocalDate) -> String? {
        newSection(titled: title, with: poolItems(named: names, on: day).map(\.id), on: day)
    }
}
