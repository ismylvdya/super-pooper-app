import Foundation
import os

/// Source of the app calendar. Services ask it at the moment they need the calendar instead of keeping a copy,
/// so after a flight every one of them works in the new time zone.
protocol CalendarSource: Sendable {
    var current: Calendar { get }
}

/// The phone's calendar (`AppCalendar`), rebuilt by `refresh()` when the system time zone changes.
final class LiveCalendar: CalendarSource {
    private let make: @Sendable () -> Calendar
    private let state: OSAllocatedUnfairLock<Calendar>

    init(make: @escaping @Sendable () -> Calendar = { AppCalendar.make() }) {
        self.make = make
        state = OSAllocatedUnfairLock(initialState: make())
    }

    var current: Calendar { state.withLock { $0 } }

    /// Forgets the zone the system cached and builds the calendar again; true when it changed.
    @discardableResult
    func refresh() -> Bool {
        NSTimeZone.resetSystemTimeZone()
        let fresh = make()
        return state.withLock { calendar in
            defer { calendar = fresh }
            return calendar != fresh
        }
    }
}

/// A calendar that never changes (previews, tests).
struct FixedCalendar: CalendarSource {
    let current: Calendar
}
