import Foundation
import Testing
@testable import SuperPooperApp

/// The days' pool sections in the App Group: each day its own snapshot, past days dropped.
struct DaySectionStoreTests {
    private let wednesday = LocalDate(TestCalendar.wednesday)

    private func withStore(_ body: (JSONDaySectionStore) throws -> Void) throws {
        let directory = VaultSandbox.baseFolder.appendingPathComponent("DaySections-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(JSONDaySectionStore(store: JSONFileStore(directory: directory)))
    }

    private func sections(on day: LocalDate, moving name: String, to section: String) -> DaySections {
        var sections = DaySections.defaults(on: day, definitions: TestConfig.rules.pool.defaultSections)
        sections.membership[name] = section
        return sections
    }

    @Test func eachDayKeepsItsOwnSnapshot() throws {
        try withStore { store in
            #expect(store.snapshot(for: wednesday) == nil)
            try store.save(sections(on: wednesday, moving: "A", to: "evening"))
            try store.save(sections(on: wednesday.adding(days: 1), moving: "A", to: "morning"))
            try store.save(sections(on: wednesday, moving: "B", to: "day"))
            #expect(store.snapshot(for: wednesday)?.membership == ["B": "day"])
            #expect(store.snapshot(for: wednesday.adding(days: 1))?.membership == ["A": "morning"])
        }
    }

    @Test func pastDaysAreDropped() throws {
        try withStore { store in
            try store.save(sections(on: wednesday.adding(days: -1), moving: "A", to: "evening"))
            try store.save(sections(on: wednesday, moving: "B", to: "evening"))
            try store.dropDays(before: wednesday)
            #expect(store.snapshot(for: wednesday.adding(days: -1)) == nil)
            #expect(store.snapshot(for: wednesday)?.membership == ["B": "evening"])
        }
    }
}
