import Foundation

/// The shown day's name on Today: "Today", "Yesterday" and "Tomorrow" by name, another day by its date and weekday
/// ("26 Oct • Wed"); in landscape today is "Tod" and another day its weekday in three letters ("Mon"). The name stands in
/// a frame as wide as the widest one the style can show (never narrower than "Yesterday"), so the arrows around it never
/// move.
enum DayName {
    enum Style { case date, weekday }

    /// The days named by a word rather than a date, by their distance from today.
    private static let named: [Int: String] = [-1: "day.yesterday", 0: "day.today", 1: "day.tomorrow"]

    static func title(_ day: LocalDate, offset: Int, style: Style, calendar: Calendar) -> String {
        switch style {
        case .weekday:
            return offset == 0 ? L10n.string("day.todayShort") : weekday(day, calendar: calendar)
        case .date:
            return named[offset].map(L10n.string) ?? dated(day, calendar: calendar)
        }
    }

    /// Every name the style shows (the named days, a date of each month on each weekday), for the frame's width.
    static func all(_ style: Style, around day: LocalDate, calendar: Calendar) -> [String] {
        switch style {
        case .weekday:
            return (0..<7).map { title(day.adding(days: $0), offset: $0, style: .weekday, calendar: calendar) }
        case .date:
            let dates = (1...12).compactMap { LocalDate(year: day.year, month: $0, day: 28) }
                .flatMap { date in (0..<7).map { date.adding(days: $0) } }
            return named.sorted { $0.key < $1.key }.map { L10n.string($0.value) } + dates.map { dated($0, calendar: calendar) }
        }
    }

    /// The widest of `names` by `width`, the one the frame is measured by.
    static func widest(_ names: [String], width: (String) -> Double) -> String? {
        names.max { width($0) < width($1) }
    }

    private static func dated(_ day: LocalDate, calendar: Calendar) -> String {
        L10n.format("day.dateAndWeekday", DateText.format(day, .dateTime.day().month(.abbreviated), calendar: calendar),
                    weekday(day, calendar: calendar))
    }

    private static func weekday(_ day: LocalDate, calendar: Calendar) -> String {
        DateText.format(day, .dateTime.weekday(.abbreviated), calendar: calendar)
    }
}
