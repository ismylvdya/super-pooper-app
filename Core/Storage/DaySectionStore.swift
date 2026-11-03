import Foundation

/// Where the days' pool sections live; replaceable (the owner may keep them elsewhere later).
protocol DaySectionStorage: Sendable {
    func snapshot(for day: LocalDate) -> DaySections?
    /// Every day kept.
    func snapshots() -> [DaySections]
    func save(_ sections: DaySections) throws
    func dropDays(before day: LocalDate) throws
}

/// Every day's sections in one App Group file next to `day-state.json`. Losing it is harmless: the days get their
/// default sections back.
struct JSONDaySectionStore: DaySectionStorage {
    static let fileName = "day-sections.json"

    let store: JSONFileStore

    func snapshot(for day: LocalDate) -> DaySections? {
        all().first { $0.day == day }
    }

    func snapshots() -> [DaySections] { all() }

    func save(_ sections: DaySections) throws {
        try write(all().filter { $0.day != sections.day } + [sections])
    }

    func dropDays(before day: LocalDate) throws {
        let all = all()
        let kept = all.filter { $0.day >= day }
        guard kept.count != all.count else { return }
        try write(kept)
    }

    private func all() -> [DaySections] {
        store.read([DaySections].self, from: Self.fileName) ?? []
    }

    private func write(_ days: [DaySections]) throws {
        try store.write(days.sorted { $0.day < $1.day }, to: Self.fileName)
    }
}
