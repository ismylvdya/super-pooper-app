import Foundation

/// The one calendar of the app and the widgets: Gregorian, weeks from Monday, the device's time zone and locale.
enum AppCalendar {
    static func make(timeZone: TimeZone = .current, locale: Locale = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = Weekday.monday.rawValue + 1
        calendar.locale = locale
        return calendar
    }
}
