import Foundation

/// The days of this Monday–Sunday week, as the test vault's `{{weekday:…}}` dates are rendered (`TestVaultRenderer`). A
/// task due on one of them waits for its day until then: a test that needs it in today's pool pretends today is that
/// day (`-SPToday`), whatever day of the week the run is on.
enum TestVaultWeek {
    enum Day: Int { case monday, tuesday, wednesday, thursday, friday, saturday, sunday }

    static func date(_ day: Day, from now: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let monday = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let date = calendar.date(byAdding: .day, value: day.rawValue, to: monday) ?? monday
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
