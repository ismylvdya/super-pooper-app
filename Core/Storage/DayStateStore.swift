import Foundation

/// App-only state that lives for one day: Skip today, the manual pool order, whether the morning review was shown and
/// the habit blocks dragged today. Losing it is harmless.
struct DayState: Codable, Equatable, Sendable {
    var day: LocalDate
    var skipped: [String] = []
    var manualOrder: [String]?
    var reviewShown = false
    /// How many data problems the banner already told about today.
    var announcedProblems = 0
    /// Tasks swiped out of today in the morning review (they come back in tomorrow's review).
    var postponed: [String] = []
    /// Habit blocks dragged on the timeline today: to another time or to the pool (`TodayTimes`).
    var timeMoves: [TimeMove] = []
    /// Blocks dragged on the timeline of another day; a later day's become that day's `timeMoves` once it comes.
    var otherDays: [DayMoves] = []

    init(day: LocalDate) { self.day = day }

    /// Fields added in later versions get their defaults when reading an older file.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(LocalDate.self, forKey: .day)
        skipped = try container.decodeIfPresent([String].self, forKey: .skipped) ?? []
        manualOrder = try container.decodeIfPresent([String].self, forKey: .manualOrder)
        reviewShown = try container.decodeIfPresent(Bool.self, forKey: .reviewShown) ?? false
        announcedProblems = try container.decodeIfPresent(Int.self, forKey: .announcedProblems) ?? 0
        postponed = try container.decodeIfPresent([String].self, forKey: .postponed) ?? []
        timeMoves = try container.decodeIfPresent([TimeMove].self, forKey: .timeMoves) ?? []
        otherDays = try container.decodeIfPresent([DayMoves].self, forKey: .otherDays) ?? []
    }

    /// The blocks moved on `day`: today's own, or those dragged on its timeline from today.
    func moves(on day: LocalDate) -> [TimeMove] {
        day == self.day ? timeMoves : otherDays.first { $0.day == day }?.moves ?? []
    }

    mutating func setMoves(_ moves: [TimeMove], on day: LocalDate) {
        guard day != self.day else {
            timeMoves = moves
            return
        }
        otherDays.removeAll { $0.day == day }
        if !moves.isEmpty { otherDays.append(DayMoves(day: day, moves: moves)) }
    }

    /// The state a new logical day starts with: empty, but with the blocks dragged on its timeline before it came, and
    /// those of the days still to come.
    func rolled(to day: LocalDate) -> DayState {
        var state = DayState(day: day)
        state.timeMoves = moves(on: day)
        state.otherDays = otherDays.filter { $0.day > day }
        return state
    }
}

/// The blocks moved on one day's timeline.
struct DayMoves: Codable, Equatable, Sendable {
    let day: LocalDate
    let moves: [TimeMove]
}

struct DayStateStore: Sendable {
    static let fileName = "day-state.json"

    let store: JSONFileStore

    func load(for day: LocalDate) -> DayState {
        guard let state = store.read(DayState.self, from: Self.fileName) else { return DayState(day: day) }
        return state.day == day ? state : state.rolled(to: day)
    }

    func save(_ state: DayState) throws {
        try store.write(state, to: Self.fileName)
    }
}
