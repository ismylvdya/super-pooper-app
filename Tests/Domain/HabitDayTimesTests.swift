import Foundation
import Testing
@testable import SuperPooperApp

/// A habit's block dragged on today's timeline (.3267): to another time or to the pool, for today only; the note keeps
/// its times. Wednesday 2026-10-21, now 08:00 unless a test says otherwise.
@Suite("Habit blocks dragged today")
struct HabitDayTimesTests {
    private let nine = LocalTime("09:00")
    private let eleven = LocalTime("11:00")
    private let evening = LocalTime("18:00")
    private let vitamins = makeHabit("Vitamins", time: "09:00")
    private let water = makeHabit("Water", status: .habit) { $0.reminderTimes = [LocalTime("09:00"), LocalTime("18:00")] }
    private let morning = TestCalendar.context(TestCalendar.wednesday, "08:00")

    private func moved(_ habit: TaskItem, _ slot: LocalTime, to time: LocalTime?) -> HabitTimeMove {
        HabitTimeMove(habit: habit.name, slot: slot, time: time)
    }

    // MARK: - The rule

    @Test func aDraggedBlockStandsAtItsNewTimeAndOneInThePoolHasNone() {
        let today = HabitDayTimes([moved(water, nine, to: eleven), moved(vitamins, nine, to: nil)])
        #expect(today.blocks(of: water) == [BlockTime(written: nine, time: eleven), BlockTime(evening)])
        #expect(today.blocks(of: vitamins).isEmpty)
        #expect(today.pooled(of: vitamins) == [nine])
        #expect(today.pooled(of: water).isEmpty)
    }

    @Test func draggedBackToItsOwnTimeItIsAsWrittenAgain() {
        let today = HabitDayTimes(HabitDayTimes([moved(water, nine, to: eleven)]).moving(water, slot: nine, to: nine))
        #expect(today.moves.isEmpty)
        #expect(today.blocks(of: water) == [BlockTime(nine), BlockTime(evening)])
    }

    /// From the pool the habit gets back its first time sent there; a habit without one has nothing to place.
    @Test func fromThePoolTheFirstTimeSentThereIsPlaced() throws {
        let pooled = HabitDayTimes([moved(water, evening, to: nil), moved(water, nine, to: nil)])
        let placed = HabitDayTimes(try #require(pooled.placing(water, at: eleven)))
        #expect(placed.blocks(of: water) == [BlockTime(written: nine, time: eleven)])
        #expect(placed.pooled(of: water) == [evening])
        #expect(HabitDayTimes().placing(water, at: eleven) == nil)
    }

    /// The habit's settings changed its times meanwhile: a move of a time the note no longer has is ignored.
    @Test func aMoveOfATimeTheNoteNoLongerHasIsIgnored() {
        let today = HabitDayTimes([moved(vitamins, LocalTime("07:00"), to: eleven)])
        #expect(today.blocks(of: vitamins) == [BlockTime(nine)])
    }

    @Test func aRenamedHabitKeepsItsMoves() {
        let renamed = HabitDayTimes([moved(vitamins, nine, to: eleven)]).renaming(from: "vitamins", to: "Pills")
        #expect(renamed == [HabitTimeMove(habit: "Pills", slot: nine, time: eleven)])
    }

    @Test func habitBlocksMoveOnlyOnTodaysTimelineAndNeverWriteTheNote() {
        #expect(TaskScheduling.canDrag(vitamins, isToday: true))
        #expect(!TaskScheduling.canDrag(vitamins, isToday: false))
        #expect(TaskScheduling.canSendToPool(vitamins, slot: nine))
        #expect(TaskScheduling.canPlace(vitamins, slot: nine, today: HabitDayTimes()))
        #expect(!TaskScheduling.canPlace(vitamins, slot: nil, today: HabitDayTimes()), "nothing of it is in the pool")
        #expect(TaskScheduling.canPlace(vitamins, slot: nil, today: HabitDayTimes([moved(vitamins, nine, to: nil)])))
        #expect(TaskScheduling.changes(scheduling: vitamins, at: TestCalendar.date(TestCalendar.wednesday, "11:00"),
                                       calendar: TestCalendar.calendar).isEmpty)
    }

    // MARK: - The day

    @Test func aDraggedBlockIsOnTodaysTimelineAtItsNewTimeNamedByItsWrittenOne() throws {
        let plan = DayScenario(tasks: [vitamins], habitMoves: [moved(vitamins, nine, to: eleven)]).build(at: morning)
        let slot = try #require(plan.slot("Vitamins"))
        #expect(clockTime(slot.start) == "11:00")
        #expect(slot.time == nine)
    }

    /// The day state is today's only: the next day's plan (and another day browsed) has the note's time.
    @Test func tomorrowTheHabitIsAsWritten() throws {
        let plan = DayScenario(tasks: [vitamins]).build(at: TestCalendar.context("2026-10-22", "08:00"))
        #expect(clockTime(try #require(plan.slot("Vitamins")).start) == "09:00")
    }

    @Test func aBlockDroppedInThePoolBringsTheHabitThere() {
        let plan = DayScenario(tasks: [vitamins], habitMoves: [moved(vitamins, nine, to: nil)]).build(at: morning)
        #expect(plan.poolNames == ["Vitamins"])
        #expect(plan.timeline.isEmpty)
    }

    /// One block of a habit with two times goes to the pool: the other stays on the timeline, and the habit stands in
    /// the pool for the one sent there until its day is closed.
    @Test func oneOfTwoBlocksInThePool() throws {
        let plan = DayScenario(tasks: [water], habitMoves: [moved(water, nine, to: nil)]).build(at: morning)
        #expect(plan.poolNames == ["Water"])
        #expect(plan.timeline.map { clockTime($0.start) } == ["18:00"])
        let closed = water.applying([.mark(.twice, on: LocalDate(TestCalendar.wednesday))])
        let done = DayScenario(tasks: [closed], habitMoves: [moved(water, nine, to: nil)]).build(at: morning)
        #expect(done.poolNames.isEmpty && done.timeline.isEmpty)
    }

    // MARK: - Notifications

    private let planner = NotificationPlanner(horizonDays: 2, limit: 64)

    /// A dragged block rings at its new time today under an identifier of its own; tomorrow's notification at the note's
    /// time takes the slot's identifier, and the slot's shown notification of today is no longer kept.
    @Test func aDraggedBlockRingsAtItsNewTimeTodayAndAsWrittenTomorrow() throws {
        let today = HabitDayTimes([moved(vitamins, nine, to: eleven)])
        let planned = planner.plan(tasks: [vitamins], reminders: [], skipped: [], habitTimes: today, context: morning)
        let slot = NotificationPlanner.habitSlot("Vitamins", nine)
        #expect(planned.map { "\(clockTime($0.fireDate)) \($0.day.isoString)" } == ["11:00 2026-10-21", "09:00 2026-10-22"])
        #expect(planned.map(\.id) == ["habit|Vitamins|2026-10-21|09:00", slot])
        #expect(planned.map(\.key) == [slot, slot])
        let valid = planner.stillValidToday(tasks: [vitamins], reminders: [], skipped: [], habitTimes: today, context: morning)
        #expect(!valid.map(\.id).contains(slot))
    }

    @Test func aBlockInThePoolDoesNotRingToday() {
        let today = HabitDayTimes([moved(vitamins, nine, to: nil)])
        let planned = planner.plan(tasks: [vitamins], reminders: [], skipped: [], habitTimes: today, context: morning)
        #expect(planned.map(\.day.isoString) == ["2026-10-22"])
        #expect(planner.stillValidToday(tasks: [vitamins], reminders: [], skipped: [], habitTimes: today, context: morning).isEmpty)
    }
}
