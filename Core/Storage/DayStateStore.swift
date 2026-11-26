import Foundation
import os

/// App-only state that lives for one day: Skip today, whether the morning review was shown and the habit blocks dragged
/// today. Losing it is harmless. The pool's order is the store's lines' (D-180).
struct DayState: Codable, Equatable, Sendable {
    var day: LocalDate
    var skipped: [String] = []
    var reviewShown = false
    /// How many data problems the banner already told about today.
    var announcedProblems = 0
    /// Habit blocks dragged on the timeline today: to another time or to the pool (`TodayTimes`).
    var timeMoves: [TimeMove] = []
    /// Blocks dragged on the timeline of another day; a later day's become that day's `timeMoves` once it comes.
    var otherDays: [DayMoves] = []
    /// Tomorrow as the morning review planned it today: it becomes that day's state once it comes.
    var ahead: Ahead?
    /// A day started before its normal boundary. The date scopes the override to that one turn.
    var earlyTurn: LocalDate?

    /// The next day planned the day before (the morning review's Tomorrow).
    struct Ahead: Codable, Equatable, Sendable {
        var day: LocalDate
        /// Habits kept out of that day.
        var skipped: [String] = []
        /// The review of that day was done the day before: it does not open by itself that morning.
        var reviewed = false
    }

    init(day: LocalDate) { self.day = day }

    /// Fields added in later versions get their defaults when reading an older file.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(LocalDate.self, forKey: .day)
        skipped = try container.decodeIfPresent([String].self, forKey: .skipped) ?? []
        reviewShown = try container.decodeIfPresent(Bool.self, forKey: .reviewShown) ?? false
        announcedProblems = try container.decodeIfPresent(Int.self, forKey: .announcedProblems) ?? 0
        timeMoves = try container.decodeIfPresent([TimeMove].self, forKey: .timeMoves) ?? []
        otherDays = try container.decodeIfPresent([DayMoves].self, forKey: .otherDays) ?? []
        ahead = try container.decodeIfPresent(Ahead.self, forKey: .ahead)
        earlyTurn = try container.decodeIfPresent(LocalDate.self, forKey: .earlyTurn)
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

    /// The state a new logical day starts with: empty, but with the blocks dragged on its timeline before it came, those
    /// of the days still to come, and what the review planned for it the day before.
    func rolled(to day: LocalDate) -> DayState {
        var state = DayState(day: day)
        state.earlyTurn = earlyTurn == day ? earlyTurn : nil
        state.timeMoves = moves(on: day)
        state.otherDays = otherDays.filter { $0.day > day }
        if let ahead, ahead.day == day {
            state.skipped = ahead.skipped
            state.reviewShown = ahead.reviewed
        }
        return state
    }

    /// The plan of tomorrow, `tomorrow`; a new one when none is kept for it.
    func plan(of tomorrow: LocalDate) -> Ahead {
        ahead?.day == tomorrow ? ahead! : Ahead(day: tomorrow)
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
    private let early: OSAllocatedUnfairLock<LocalDate?>

    init(store: JSONFileStore) {
        self.store = store
        early = OSAllocatedUnfairLock(initialState: store.read(DayState.self, from: Self.fileName)?.earlyTurn)
    }

    /// Shared by the app and the task store, which reads today's date off the main actor.
    var earlyTurn: LocalDate? { early.withLock { $0 } }

    func load(for context: DayContext) -> DayState {
        guard let state = store.read(DayState.self, from: Self.fileName) else { return DayState(day: context.today) }
        let day = context.advancingEarly(to: state.earlyTurn).today
        return state.day == day ? state : state.rolled(to: day)
    }

    func save(_ state: DayState) throws {
        try early.withLock { day in
            try store.write(state, to: Self.fileName)
            day = state.earlyTurn
        }
    }
}
