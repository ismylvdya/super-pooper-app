import Foundation

/// "Today", "Tomorrow, 25 Oct", "Yesterday, 23 Oct", "Mon, 27 Oct" for the shown day on Today.
enum DayName {
    static func format(_ day: LocalDate, offset: Int, calendar: Calendar) -> String {
        let date = day.startDate(in: calendar)
        let short = date.formatted(.dateTime.day().month(.abbreviated))
        switch offset {
        case 0: return L10n.string("day.today")
        case 1: return L10n.format("day.tomorrow", short)
        case -1: return L10n.format("day.yesterday", short)
        default: return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        }
    }

    /// The same without the date where a word says it ("Tomorrow"), for a narrow bar.
    static func short(_ day: LocalDate, offset: Int, calendar: Calendar) -> String {
        switch offset {
        case 0: L10n.string("day.today")
        case 1: L10n.string("day.tomorrow.short")
        case -1: L10n.string("day.yesterday.short")
        default: day.startDate(in: calendar).formatted(.dateTime.day().month(.abbreviated))
        }
    }
}
