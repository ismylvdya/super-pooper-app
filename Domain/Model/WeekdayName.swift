import Foundation

/// Weekday and month names in the calendar's language, so every screen spells them the same way.
extension Weekday {
    enum NameStyle { case full, short, initial }

    /// "Monday", "Mon" or "M".
    func name(_ style: NameStyle, in calendar: Calendar) -> String {
        let symbols = switch style {
        case .full: calendar.weekdaySymbols
        case .short: calendar.shortWeekdaySymbols
        case .initial: calendar.veryShortStandaloneWeekdaySymbols
        }
        return symbols[rawValue % 7]
    }
}

enum MonthName {
    /// "J" for January (month 1…12).
    static func initial(_ month: Int, in calendar: Calendar) -> String {
        calendar.veryShortStandaloneMonthSymbols[month - 1]
    }
}
