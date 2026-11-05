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
    /// "January" (month 1…12), as it stands alone rather than in a date.
    static func full(_ month: Int, in calendar: Calendar) -> String {
        calendar.standaloneMonthSymbols[month - 1]
    }
}
