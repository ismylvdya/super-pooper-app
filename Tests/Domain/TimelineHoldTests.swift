import Foundation
import Testing
@testable import SuperPooperApp

/// A "+" let go on the timeline and a hold on its empty space put a new item by one rule: the moment there on the drop
/// step, as a dragged task gets it.
struct TimelineHoldTests {
    private let calendar = TestCalendar.calendar
    private let windowStart = TestCalendar.date(TestCalendar.wednesday, "04:00")

    @Test func aHoldAndADropAtTheSameSpotGiveTheSamePlacement() {
        let offset = 11.4 * 60.0
        let held = TaskScheduling.placement(atOffset: offset, windowStart: windowStart, hourHeight: 60, stepMinutes: 15,
                                            calendar: calendar)
        let dropped = TaskScheduling.moment(atOffset: offset, windowStart: windowStart, hourHeight: 60, stepMinutes: 15,
                                            calendar: calendar)
        #expect(held == .timeline(at: dropped, calendar: calendar))
        #expect(held == .timeline(day: LocalDate(TestCalendar.wednesday), time: LocalTime("15:30")))
    }

    /// Past midnight the spot is the next date's, as a task dragged there gets it.
    @Test func pastMidnightItIsTheNextDate() {
        let held = TaskScheduling.placement(atOffset: 21 * 60, windowStart: windowStart, hourHeight: 60, stepMinutes: 15,
                                            calendar: calendar)
        #expect(held == .timeline(day: LocalDate("2026-10-22"), time: LocalTime("01:00")))
    }

    @Test func aTimelinePlacementPresetsATaskDateAndAHabitReminder() {
        let placement = NewItemPlacement.timeline(day: LocalDate("2026-11-06"), time: LocalTime("15:30"))
        #expect(placement.presets(.task) == [.due(TaskDue(day: LocalDate("2026-11-06"), time: LocalTime("15:30")))])
        #expect(placement.presets(.habit) == [.reminderTimes([LocalTime("15:30")])])
        #expect(NewItemPlacement.pool(order: [], section: nil, day: LocalDate("2026-11-06")).presets(.task).isEmpty)
    }

    @Test func thePoolsGapBecomesTheNotesName() {
        let placement = NewItemPlacement.pool(order: ["A", NewItemPlacement.gap, "B"], section: "day", day: LocalDate("2026-11-06"))
        #expect(placement.poolOrder(named: "New") == ["A", "New", "B"])
        #expect(NewItemPlacement.timeline(day: LocalDate("2026-11-06"), time: LocalTime("15:30")).poolOrder(named: "New") == nil)
    }
}
