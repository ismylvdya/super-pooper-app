import Foundation

extension RulesConfig.EventLinks {
    /// Apple Calendar opened on the day and hour of `date`.
    func calendarURL(at date: Date) -> URL? {
        URL(string: "\(calendarAppURL)\(Int(date.timeIntervalSinceReferenceDate))")
    }

    /// The reminder opened in Apple Reminders.
    func reminderURL(id: String) -> URL? {
        URL(string: remindersAppURL + id)
    }
}
