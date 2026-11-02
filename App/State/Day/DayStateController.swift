import Foundation
import Observation

/// The logical day and what the user decided about it today: Skip today, Not today, the pool's manual order, the habit
/// blocks dragged on the timeline, the morning review shown, the problems already announced. Kept in the App Group for this day only; a new day starts empty. The
/// calendar is the app calendar as it is now: a new time zone renews it (`refreshCalendar`).
@MainActor
@Observable
final class DayStateController {
    let clock: Clock
    private(set) var calendar: Calendar
    private(set) var dayState: DayState
    @ObservationIgnored private let calendarSource: CalendarSource
    @ObservationIgnored private let store: DayStateStore
    @ObservationIgnored private let settings: SettingsController

    init(clock: Clock, calendar: CalendarSource, store: DayStateStore, settings: SettingsController) {
        self.clock = clock
        calendarSource = calendar
        self.calendar = calendar.current
        self.store = store
        self.settings = settings
        let day = settings.settings.day
        let today = DayContext(now: clock.now, calendar: calendar.current, boundary: day.boundary, energyHour: day.energyHour).today
        dayState = store.load(for: today)
    }

    func context(at date: Date? = nil) -> DayContext {
        let day = settings.settings.day
        return DayContext(now: date ?? clock.now, calendar: calendar, boundary: day.boundary, energyHour: day.energyHour)
    }

    /// The tasks as the day sees them: times kept in a zone of their own moved to the phone's clock (`ZonedTimes`).
    func local(_ tasks: [TaskItem]) -> [TaskItem] {
        let context = context()
        return ZonedTimes.local(tasks, calendar: context.calendar, today: context.today)
    }

    func local(_ task: TaskItem) -> TaskItem {
        let context = context()
        return ZonedTimes.local(task, calendar: context.calendar, today: context.today)
    }

    /// The phone moved to another time zone or its clock jumped: the calendar as it is now.
    func refreshCalendar() {
        calendar = calendarSource.current
    }

    /// Today's names taken out of today in the morning review; none once the day is over.
    var postponedNames: [String] {
        dayState.day == context().today ? dayState.postponed : []
    }

    /// Habit blocks dragged on the timeline today; none once the day is over.
    var todayTimes: TodayTimes {
        TodayTimes(dayState.day == context().today ? dayState.timeMoves : [])
    }

    func setTimeMoves(_ moves: [TimeMove]) {
        update { $0.timeMoves = moves }
    }

    /// The blocks moved on `day`'s timeline (today's, or another day's).
    func times(on day: LocalDate) -> TodayTimes {
        rollDayIfNeeded()
        return TodayTimes(dayState.moves(on: day))
    }

    func setTimeMoves(_ moves: [TimeMove], on day: LocalDate) {
        update { $0.setMoves(moves, on: day) }
    }

    func rollDayIfNeeded() {
        let today = context().today
        guard dayState.day != today else { return }
        dayState = dayState.rolled(to: today)
        try? store.save(dayState)
    }

    func skip(_ name: String) {
        update { if !$0.skipped.containsNoteName(name) { $0.skipped.append(name) } }
    }

    func postpone(_ name: String) {
        update { if !$0.postponed.containsNoteName(name) { $0.postponed.append(name) } }
    }

    func unpostpone(_ name: String) {
        update { $0.postponed.removeAll { $0.isSameNoteName(as: name) } }
    }

    /// The pool's order for today; nil goes back to the automatic sort.
    func setManualOrder(_ names: [String]?) {
        update { $0.manualOrder = names }
    }

    func markReviewShown() {
        update { $0.reviewShown = true }
    }

    /// Records how many problems the day has; true when there are more than the user was last told about.
    func announceProblems(_ count: Int) -> Bool {
        let isNew = count > dayState.announcedProblems
        update { $0.announcedProblems = count }
        return isNew
    }

    /// Undo: what an action decided about today goes back (Skip today, Not today, the manual order, the moved blocks),
    /// as long as it is still the same day.
    func restore(_ before: DayState) {
        rollDayIfNeeded()
        guard before.day == dayState.day else { return }
        update {
            $0.skipped = before.skipped
            $0.postponed = before.postponed
            $0.manualOrder = before.manualOrder
            $0.timeMoves = before.timeMoves
        }
    }

    /// A renamed note keeps its place in today's lists.
    func followRename(from old: String, to new: String) {
        let rename = { (names: [String]) in NameReferences.renaming(names, from: old, to: new) }
        update {
            $0.skipped = rename($0.skipped)
            $0.postponed = rename($0.postponed)
            $0.manualOrder = $0.manualOrder.map(rename)
            $0.timeMoves = TodayTimes($0.timeMoves).renaming(from: old, to: new)
        }
    }

    private func update(_ change: (inout DayState) -> Void) {
        rollDayIfNeeded()
        change(&dayState)
        try? store.save(dayState)
    }
}
