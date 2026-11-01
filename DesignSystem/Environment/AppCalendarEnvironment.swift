import SwiftUI

extension View {
    /// The app calendar and its zone for the views: date pickers and dates draw in the same zone the logic converts
    /// with (SwiftUI takes the zone from `\.timeZone`, not from the calendar).
    func appCalendar(_ calendar: Calendar) -> some View {
        environment(\.calendar, calendar).environment(\.timeZone, calendar.timeZone)
    }
}
