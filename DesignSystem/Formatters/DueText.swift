import SwiftUI

enum DueText {
    /// Counted in logical days: 01:00 after midnight is still tonight, shown as a time of today.
    static func format(_ due: TaskDue, context: DayContext) -> String {
        let calendar = context.calendar
        let distance = context.today.days(until: context.logicalDay(of: due))
        let dayText: String
        switch distance {
        case 0: dayText = L10n.string("due.today")
        case 1: dayText = L10n.string("due.tomorrow")
        case -1: dayText = L10n.string("due.yesterday")
        case 2...6: dayText = due.day.weekday.name(.short, in: calendar)
        default: dayText = due.day.startDate(in: calendar).formatted(.dateTime.month(.abbreviated).day())
        }
        guard let time = due.time else { return dayText }
        return distance == 0 ? time.string : L10n.format("due.dayAndTime", dayText, time.string)
    }
}
