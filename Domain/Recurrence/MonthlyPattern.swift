import Foundation

/// How a monthly repeat is chosen, as in Apple Calendar: "Each" day number of the month, or "On the" first,
/// second, third, fourth or last day or weekday of the month.
struct MonthlyPattern: Hashable, Sendable {
    enum Mode: Hashable, Sendable, CaseIterable {
        case each
        case onThe
    }

    enum Ordinal: Int, Hashable, Sendable, CaseIterable {
        case first = 1, second, third, fourth
        case last = -1
    }

    enum Kind: Hashable, Sendable {
        case day
        case weekday(Weekday)

        static let all: [Kind] = [.day] + Weekday.allCases.map(Kind.weekday)
    }

    var ordinal: Ordinal
    var kind: Kind

    /// The rule's day: the first to fourth day of the month is that day number, the last day is `-1`.
    var monthlyDay: RecurrenceDraft.MonthlyDay {
        switch kind {
        case .day: ordinal == .last ? .lastDayOfMonth : .dayOfMonth(ordinal.rawValue)
        case .weekday(let weekday): .weekday(ordinal: ordinal.rawValue, weekday: weekday)
        }
    }

    /// The pattern of an "On the" rule day; nil for a day number that is not first to fourth.
    init?(_ day: RecurrenceDraft.MonthlyDay) {
        switch day {
        case .lastDayOfMonth:
            self.init(ordinal: .last, kind: .day)
        case .dayOfMonth(let number):
            guard let ordinal = Ordinal(rawValue: number) else { return nil }
            self.init(ordinal: ordinal, kind: .day)
        case .weekday(let number, let weekday):
            guard let ordinal = Ordinal(rawValue: number) else { return nil }
            self.init(ordinal: ordinal, kind: .weekday(weekday))
        }
    }

    init(ordinal: Ordinal, kind: Kind) {
        self.ordinal = ordinal
        self.kind = kind
    }

    /// A rule read back: the first and the last day and any weekday are "On the", other day numbers "Each".
    static func mode(of day: RecurrenceDraft.MonthlyDay) -> Mode {
        switch day {
        case .dayOfMonth(let number): number == 1 ? .onThe : .each
        case .lastDayOfMonth, .weekday: .onThe
        }
    }
}
