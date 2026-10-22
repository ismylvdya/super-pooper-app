import Foundation

/// App-only state that lives for one day: Skip today, the manual pool order and whether the
/// morning review was shown. Losing it is harmless.
struct DayState: Codable, Equatable, Sendable {
    var day: LocalDate
    var skipped: [String] = []
    var manualOrder: [String]?
    var reviewShown = false
}

struct DayStateStore: Sendable {
    static let fileName = "day-state.json"

    let store: JSONFileStore

    func load(for day: LocalDate) -> DayState {
        guard let state = store.read(DayState.self, from: Self.fileName), state.day == day else { return DayState(day: day) }
        return state
    }

    func save(_ state: DayState) throws {
        try store.write(state, to: Self.fileName)
    }
}
