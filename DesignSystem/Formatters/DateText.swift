import Foundation

/// Dates and times as text in the app calendar — its zone and locale, not the system's — so the day shown is the day
/// the logic means, even in the moment the two differ.
enum DateText {
    static func format(_ date: Date, _ style: Date.FormatStyle, calendar: Calendar) -> String {
        var style = style
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        if let locale = calendar.locale { style.locale = locale }
        return date.formatted(style)
    }

    static func format(_ day: LocalDate, _ style: Date.FormatStyle, calendar: Calendar) -> String {
        format(day.startDate(in: calendar, offset: .noon), style, calendar: calendar)
    }
}
