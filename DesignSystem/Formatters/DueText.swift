import SwiftUI

enum DueText {
    static func format(_ due: TaskDue, today: LocalDate, calendar: Calendar) -> String {
        let distance = today.days(until: due.day)
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
