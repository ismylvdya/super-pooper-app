import Foundation
import Observation

/// The pool sections of each day: the snapshot a day was arranged into (`DaySectionStorage`), or the default sections
/// for a day without one. Renamed notes keep their places; deleted ones leave every day; past days are dropped.
@MainActor
@Observable
final class DaySectionsController {
    /// Bumped on every change, so whoever read a snapshot is drawn again.
    private var version = 0
    @ObservationIgnored private var loaded: [LocalDate: DaySections] = [:]
    @ObservationIgnored private let store: DaySectionStorage
    @ObservationIgnored private let day: DayStateController
    @ObservationIgnored let definitions: [PoolSectionDefinition]

    init(store: DaySectionStorage, day: DayStateController, definitions: [PoolSectionDefinition]) {
        self.store = store
        self.day = day
        self.definitions = definitions
        rollDayIfNeeded()
    }

    /// The day's stored sections, or the defaults.
    func snapshot(on date: LocalDate) -> DaySections {
        _ = version
        if let known = loaded[date] { return known }
        let snapshot = store.snapshot(for: date) ?? .defaults(on: date, definitions: definitions)
        loaded[date] = snapshot
        return snapshot
    }

    /// Every stored day, as it is now (Undo keeps them).
    func storedSnapshots() -> [DaySections] { store.snapshots() }

    func update(on date: LocalDate, _ change: (inout DaySections) -> Void) {
        var sections = snapshot(on: date)
        change(&sections)
        save(sections)
    }

    func followRename(from old: String, to new: String) {
        for sections in store.snapshots() { save(sections.renaming(from: old, to: new), ifChangedFrom: sections) }
    }

    func forget(_ names: [String]) {
        for sections in store.snapshots() { save(sections.removing(names), ifChangedFrom: sections) }
    }

    /// Undo: the days as they were before the action.
    func restore(_ before: [DaySections]) {
        let now = store.snapshots()
        for sections in before where !now.contains(sections) { save(sections) }
    }

    func rollDayIfNeeded() {
        let today = day.context().today
        try? store.dropDays(before: today)
        loaded = loaded.filter { $0.key >= today }
    }

    private func save(_ sections: DaySections, ifChangedFrom old: DaySections? = nil) {
        guard sections != old else { return }
        try? store.save(sections)
        loaded[sections.day] = sections
        version += 1
    }
}
