import Foundation

/// App-only state that lives for one day: Skip today, the manual pool order and whether the
/// morning review was shown. Losing it is harmless.
struct DayState: Codable, Equatable, Sendable {
    var day: LocalDate
    var skipped: [String] = []
    var manualOrder: [String]?
    var reviewShown = false
    /// How many data problems the banner already told about today.
    var announcedProblems = 0

    init(day: LocalDate) { self.day = day }

    /// Fields added in later versions get their defaults when reading an older file.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(LocalDate.self, forKey: .day)
        skipped = try container.decodeIfPresent([String].self, forKey: .skipped) ?? []
        manualOrder = try container.decodeIfPresent([String].self, forKey: .manualOrder)
        reviewShown = try container.decodeIfPresent(Bool.self, forKey: .reviewShown) ?? false
        announcedProblems = try container.decodeIfPresent(Int.self, forKey: .announcedProblems) ?? 0
    }
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
