import Foundation
import Testing
@testable import SuperPooper

/// The quick chips of a task, dragging tasks between the pool and the timeline, and swipes on Today.
@Suite("Quick planning")
struct QuickPlanningTests {
    private let today = LocalDate(TestCalendar.wednesday)

    // MARK: - Today / Tomorrow chips

    @Test func theChipsWorkLikeRadioButtons() {
        let context = TestCalendar.context()
        #expect(QuickDue.selection(of: nil, context: context) == nil)
        let onToday = QuickDue.toggling(.today, due: nil, context: context)
        #expect(onToday == TaskDue(day: today))
        #expect(QuickDue.selection(of: onToday, context: context) == .today)
        let onTomorrow = QuickDue.toggling(.tomorrow, due: onToday, context: context)
        #expect(onTomorrow == TaskDue(day: LocalDate("2026-10-22")))
        #expect(QuickDue.toggling(.tomorrow, due: onTomorrow, context: context) == nil)
    }

    @Test func anotherDateSelectsNoChipAndATimeIsKept() {
        let context = TestCalendar.context()
        let friday = TaskDue(day: LocalDate("2026-10-23"), time: LocalTime("18:00"))
        #expect(QuickDue.selection(of: friday, context: context) == nil)
        #expect(QuickDue.toggling(.today, due: friday, context: context) == TaskDue(day: today, time: LocalTime("18:00")))
    }

    // MARK: - Pool ↔ timeline

    @Test func aTaskDroppedOnTheTimelineGetsThatDateAndTime() {
        let task = makeTask("Позвонить в банк")
        let moment = TestCalendar.date(TestCalendar.wednesday, "14:35")
        #expect(TaskScheduling.changes(scheduling: task, at: moment, calendar: TestCalendar.calendar)
                == [.due(TaskDue(day: today, time: LocalTime("14:35")))])
    }

    @Test func aTaskDraggedBackToThePoolKeepsItsDateAndLosesItsTime() {
        let context = TestCalendar.context()
        let timed = makeTask("Позвонить в банк") { $0.due = TaskDue("2026-10-21T14:35") }
        #expect(TaskScheduling.changes(unscheduling: timed, context: context) == [.due(TaskDue(day: today))])
        #expect(TaskScheduling.changes(unscheduling: makeTask("Без времени"), context: context).isEmpty)
    }

    /// Dropped at 00:30 it was tonight; back in the pool it stays today, not tomorrow.
    @Test func aTaskAfterMidnightGoesBackToThePoolOnItsLogicalDay() {
        let night = makeTask("Ночная") { $0.due = TaskDue("2026-10-22T00:30") }
        #expect(TaskScheduling.changes(unscheduling: night, context: TestCalendar.context()) == [.due(TaskDue(day: today))])
    }

    @Test func aTaskAfterMidnightIsToday() {
        let context = TestCalendar.context()
        let night = TaskDue("2026-10-22T01:00")
        #expect(QuickDue.selection(of: night, context: context) == .today)
        #expect(QuickDue.toggling(.tomorrow, due: night, context: context) == TaskDue("2026-10-23T01:00"))
    }

    @Test func habitsAreNotMovedByDragging() {
        let habit = makeHabit("Vitamins", time: "09:00")
        #expect(!TaskScheduling.canMove(habit))
        #expect(TaskScheduling.changes(scheduling: habit, at: TestCalendar.date(TestCalendar.wednesday, "10:00"),
                                       calendar: TestCalendar.calendar).isEmpty)
        #expect(TaskScheduling.changes(unscheduling: habit, context: TestCalendar.context()).isEmpty)
    }

    @Test func theSpotUnderTheFingerIsRoundedToTheStep() {
        let start = TestCalendar.date(TestCalendar.wednesday, "12:00")
        let moment = { (offset: Double) in
            TaskScheduling.moment(atOffset: offset, windowStart: start, hourHeight: 60, stepMinutes: 5, calendar: TestCalendar.calendar)
        }
        #expect(clockTime(moment(0)) == "12:00")
        #expect(clockTime(moment(37)) == "12:35")
        #expect(clockTime(moment(38)) == "12:40")
        #expect(clockTime(moment(-20)) == "12:00")
        #expect(clockTime(moment(150)) == "14:30")
    }

    @Test func theDraggedTaskGoesInFrontOfTheFirstRowBelowTheFinger() {
        let rows = [PoolDropOrder.Row(id: "A", midY: 20), PoolDropOrder.Row(id: "B", midY: 60), PoolDropOrder.Row(id: "C", midY: 100)]
        #expect(PoolDropOrder.order(rows: rows, dragged: "C", at: 10) == ["C", "A", "B"])
        #expect(PoolDropOrder.order(rows: rows, dragged: "A", at: 70) == ["B", "A", "C"])
        #expect(PoolDropOrder.order(rows: rows, dragged: "A", at: 500) == ["B", "C", "A"])
        // A task from the timeline is not a row yet.
        #expect(PoolDropOrder.order(rows: rows, dragged: "T", at: 40) == ["A", "T", "B", "C"])
    }

    // MARK: - Swipes

    /// A swipe only turns the pages; past the edge it does nothing (days change with the buttons).
    @Test func onPagesASwipeTurnsThePageAndStopsAtTheEdge() {
        #expect(TodaySwipe.page(forward: true, page: 0, pageCount: 2) == 1)
        #expect(TodaySwipe.page(forward: true, page: 1, pageCount: 2) == nil)
        #expect(TodaySwipe.page(forward: false, page: 1, pageCount: 2) == 0)
        #expect(TodaySwipe.page(forward: false, page: 0, pageCount: 2) == nil)
        #expect(TodaySwipe.page(forward: true, page: 0, pageCount: 1) == nil)
    }

    /// The first movement decides the direction: a vertical scroll that later drifts sideways never turns the page.
    @Test func aDragKeepsTheDirectionOfItsFirstMovement() {
        #expect(TodaySwipe.axis(locked: nil, width: 4, height: 30, axisRatio: 1.5) == .vertical)
        #expect(TodaySwipe.axis(locked: .vertical, width: 200, height: 30, axisRatio: 1.5) == .vertical)
        #expect(TodaySwipe.axis(locked: .horizontal, width: 40, height: 90, axisRatio: 1.5) == .horizontal)
        #expect(!TodaySwipe.isSwipe(axis: .vertical, width: 300, predictedWidth: 300, containerWidth: 375, threshold: 0.25))
        #expect(TodaySwipe.isSwipe(axis: .horizontal, width: 120, predictedWidth: 120, containerWidth: 375, threshold: 0.25))
    }

    @Test func theWidgetHasNoPages() {
        #expect(AppSettings.TodayArrangement.paged.forWidget == .sideBySide)
        #expect(AppSettings.TodayArrangement.stacked.forWidget == .stacked)
        #expect(TestConfig.defaults.today.arrangement == .paged)
        #expect(TestConfig.defaults.today.widgetArrangement == .sideBySide)
    }
}
