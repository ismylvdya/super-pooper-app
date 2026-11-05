import SwiftUI

/// A system date picker bound to a wall-clock day. The picker draws in the environment's calendar and zone (the app
/// calendar, `.appCalendar`) and the binding converts through that same calendar, so the day tapped is the day written.
struct DayField: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.tokens) private var tokens
    private let title: LocalizedStringKey
    @Binding private var day: LocalDate

    init(_ title: LocalizedStringKey, day: Binding<LocalDate>) {
        self.title = title
        _day = day
    }

    var body: some View {
        DatePicker(title, selection: Binding(get: { Self.date(of: day, calendar: calendar) },
                                             set: { day = LocalDate($0, in: calendar) }),
                   displayedComponents: .date)
            .tint(tokens.color(.accentCalendar))
    }

    /// The picker keeps the time of day when another day is tapped; at noon that never tips into a neighbouring date.
    static func date(of day: LocalDate, calendar: Calendar) -> Date {
        day.startDate(in: calendar, offset: .noon)
    }
}

/// A compact hour-and-minute picker bound to a wall-clock time, shown on `day` (the clock of that date decides
/// which times exist), through the environment's calendar like `DayField`.
struct TimeField: View {
    @Environment(\.calendar) private var calendar
    private let title: LocalizedStringKey
    @Binding private var time: LocalTime
    private let day: LocalDate

    init(_ title: LocalizedStringKey = "", time: Binding<LocalTime>, on day: LocalDate) {
        self.title = title
        _time = time
        self.day = day
    }

    var body: some View {
        DatePicker(title, selection: Binding(get: { day.startDate(in: calendar, offset: time) },
                                             set: { time = LocalTime($0, in: calendar) }),
                   displayedComponents: .hourAndMinute)
    }
}
