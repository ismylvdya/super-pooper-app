import Foundation
import Testing
@testable import SuperPooper

/// The quick chips of a task, dragging tasks between the pool and the timeline, and swipes on Today.
@Suite("Quick planning")
struct QuickPlanningTests {
    private let today = LocalDate(TestCalendar.wednesday)

    // MARK: - Today / Tomorrow chips

    @Test func theChipsWorkLikeRadioButtons() {
        #expect(QuickDue.selection(of: nil, today: today) == nil)
        let onToday = QuickDue.toggling(.today, due: nil, today: today)
        #expect(onToday == TaskDue(day: today))
        #expect(QuickDue.selection(of: onToday, today: today) == .today)
        let onTomorrow = QuickDue.toggling(.tomorrow, due: onToday, today: today)
        #expect(onTomorrow == TaskDue(day: LocalDate("2026-10-22")))
        #expect(QuickDue.toggling(.tomorrow, due: onTomorrow, today: today) == nil)
    }

    @Test func anotherDateSelectsNoChipAndATimeIsKept() {
        let friday = TaskDue(day: LocalDate("2026-10-23"), time: LocalTime("18:00"))
        #expect(QuickDue.selection(of: friday, today: today) == nil)
        #expect(QuickDue.toggling(.today, due: friday, today: today) == TaskDue(day: today, time: LocalTime("18:00")))
    }

    // MARK: - Pool ↔ timeline

    @Test func aTaskDroppedOnTheTimelineGetsThatDateAndTime() {
        let task = makeTask("Позвонить в банк")
        let moment = TestCalendar.date(TestCalendar.wednesday, "14:35")
        #expect(TaskScheduling.changes(scheduling: task, at: moment, calendar: TestCalendar.calendar)
                == [.due(TaskDue(day: today, time: LocalTime("14:35")))])
    }

    @Test func aTaskDraggedBackToThePoolKeepsItsDateAndLosesItsTime() {
        let timed = makeTask("Позвонить в банк") { $0.due = TaskDue("2026-10-21T14:35") }
        #expect(TaskScheduling.changes(unscheduling: timed) == [.due(TaskDue(day: today))])
        #expect(TaskScheduling.changes(unscheduling: makeTask("Без времени")).isEmpty)
    }

    @Test func habitsAreNotMovedByDragging() {
        let habit = makeHabit("Vitamins", time: "09:00")
        #expect(!TaskScheduling.canMove(habit))
        #expect(TaskScheduling.changes(scheduling: habit, at: TestCalendar.date(TestCalendar.wednesday, "10:00"),
                                       calendar: TestCalendar.calendar).isEmpty)
        #expect(TaskScheduling.changes(unscheduling: habit).isEmpty)
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

    @Test func onPagesASwipeTurnsThePageBeforeItChangesTheDay() {
        #expect(TodaySwipe.move(forward: true, page: 0, pageCount: 2) == .page(1))
        #expect(TodaySwipe.move(forward: true, page: 1, pageCount: 2) == .day(1))
        #expect(TodaySwipe.move(forward: false, page: 1, pageCount: 2) == .page(0))
        #expect(TodaySwipe.move(forward: false, page: 0, pageCount: 2) == .day(-1))
        #expect(TodaySwipe.move(forward: true, page: 0, pageCount: 1) == .day(1))
    }

    @Test func theWidgetHasNoPages() {
        #expect(AppSettings.TodayArrangement.paged.forWidget == .sideBySide)
        #expect(AppSettings.TodayArrangement.stacked.forWidget == .stacked)
        #expect(TestConfig.defaults.today.arrangement == .paged)
        #expect(TestConfig.defaults.today.widgetArrangement == .sideBySide)
    }
}
