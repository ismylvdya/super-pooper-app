import Foundation

/// The shown day's name on Today: "Today", another day by its date ("26 Oct"); in landscape every day by its
/// weekday in two letters ("Mo"). The name stands in a frame as wide as the widest one the style can show, so the
/// arrows around it never move.
enum DayName {
    enum Style { case date, weekday }

    static func title(_ day: LocalDate, offset: Int, style: Style, calendar: Calendar) -> String {
        switch style {
        case .weekday: format(day, .dateTime.weekday(.short), calendar: calendar)
        case .date: offset == 0 ? L10n.string("day.today") : format(day, .dateTime.day().month(.abbreviated), calendar: calendar)
        }
    }

    /// Every name the style shows (a date of each month, each weekday), for the frame's width.
    static func all(_ style: Style, around day: LocalDate, calendar: Calendar) -> [String] {
        switch style {
        case .weekday:
            return (0..<7).map { title(day.adding(days: $0), offset: $0, style: .weekday, calendar: calendar) }
        case .date:
            let dates = (1...12).compactMap { LocalDate(year: day.year, month: $0, day: 28) }
            return [L10n.string("day.today")] + dates.map { title($0, offset: 1, style: .date, calendar: calendar) }
        }
    }

    private static func format(_ day: LocalDate, _ style: Date.FormatStyle, calendar: Calendar) -> String {
        var style = style
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        if let locale = calendar.locale { style.locale = locale }
        return day.startDate(in: calendar).formatted(style)
    }
}
