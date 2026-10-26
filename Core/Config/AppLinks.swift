import Foundation

extension RulesConfig.EventLinks {
    /// Apple Calendar opened on the day and hour of `date`.
    func calendarURL(at date: Date) -> URL? {
        URL(string: "\(calendarAppURL)\(Int(date.timeIntervalSinceReferenceDate))")
    }

    /// The shortcut of that name run by the Shortcuts app.
    func shortcutURL(named name: String) -> URL? {
        name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).flatMap { URL(string: shortcutsRunURL + $0) }
    }

    /// The reminder opened in Apple Reminders.
    func reminderURL(id: String) -> URL? {
        URL(string: remindersAppURL + id)
    }
}
