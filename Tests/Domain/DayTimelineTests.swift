import Foundation
import Testing
@testable import SuperPooperApp

/// Pool vs timeline (`<day_logic>` "Таймлайн", "Пул", "Расстановка на таймлайне").
/// Wednesday 2026-10-21; "Call with dad" is 19:00–20:00; "now" is 13:25 unless a test says otherwise.
@Suite("Day pool and timeline")
struct DayTimelineTests {
    private let call = makeEvent("Call with dad", from: "19:00", to: "20:00")

    // MARK: - Timed tasks
    @Test func onlyPastEventsAreGreyedOutWhileDoneEntriesLeave() throws {
        let morning = makeEvent("Standup", from: "10:00", to: "10:15")
        let doneTimed = makeHabit("Vitamins", time: "09:00") { $0.marks = [LocalDate("2026-10-21"): .done] }
        let openTimed = makeTask("Missed at noon") { $0.due = TaskDue("2026-10-21T12:00") }
        let reminders = [makeReminder("Done reminder", at: "16:00", completed: true), makeReminder("Past reminder", at: "11:00")]
        let plan = DayScenario(tasks: [doneTimed, openTimed], events: [morning, call], reminders: reminders).build()

        #expect(plan.eventSlot("Standup")?.isPast == true)
        #expect(plan.eventSlot("Call with dad")?.isPast == false)
        #expect(plan.slot("Vitamins") == nil)
        #expect(plan.slot("Missed at noon")?.isPast == false)
        let reminderSlots = plan.timeline.filter { if case .reminder = $0.content { return true } else { return false } }
        #expect(reminderSlots.count == 1 && !reminderSlots[0].isPast)
    }


    @Test func aTaskDueTodayWithTimeIsOnTheTimelineAtItsTime() throws {
        let parcel = makeTask("Pick up parcel") { $0.due = TaskDue("2026-10-21T16:00"); $0.timeEstimate = 60 }
        let plan = DayScenario(tasks: [parcel]).build()
        let slot = try #require(plan.slot("Pick up parcel"))
        #expect(plan.poolNames.isEmpty)
        #expect((clockTime(slot.start), clockTime(slot.end)) == ("16:00", "17:00"))
        #expect(!slot.isPast)
    }

    /// Due today without a time and overdue tasks are in the pool; a task dated later this week waits for its day.
    @Test func dueWithoutTimeOrOverdueStaysInThePoolALaterOneWaits() {
        let today = makeTask("Due today") { $0.due = TaskDue("2026-10-21") }
        let friday = makeTask("Friday at ten") { $0.due = TaskDue("2026-10-23T10:00") }
        let tomorrow = makeTask("Tomorrow") { $0.due = TaskDue("2026-10-22") }
        let overdue = makeTask("Yesterday at ten") { $0.due = TaskDue("2026-10-20T10:00") }
        let plan = DayScenario(tasks: [today, friday, tomorrow, overdue]).build()
        #expect(Set(plan.poolNames) == ["Due today", "Yesterday at ten"])
        #expect(plan.timeline.isEmpty)
        let fridayPlan = DayScenario(tasks: [today, friday, tomorrow, overdue]).build(at: TestCalendar.context("2026-10-23", "08:00"))
        #expect(fridayPlan.timelineTaskNames == ["Friday at ten"])
    }

    /// A done habit leaves the timeline; with two reminders a day each mark takes away one block, earliest first.
    @Test func eachMarkOfAHabitTakesOneReminderBlockOffTheTimeline() {
        let today = LocalDate(isoString: "2026-10-21")!
        func water(_ configure: (inout TaskItem) -> Void = { _ in }) -> TaskItem {
            makeHabit("Water") { task in
                task.reminderTimes = [LocalTime(string: "18:00")!, LocalTime(string: "09:00")!]
                configure(&task)
            }
        }
        func times(_ task: TaskItem) -> [String] {
            DayScenario(tasks: [task]).build(at: TestCalendar.context(TestCalendar.wednesday, "08:00")).timeline.map { clockTime($0.start) }
        }
        #expect(times(water()) == ["09:00", "18:00"])
        #expect(times(water { $0.marks = [today: .done] }) == ["18:00"])
        #expect(times(water { $0.marks = [today: .twice] }).isEmpty)
        let once = makeHabit("Vitamins", time: "09:00") { $0.marks = [today: .done] }
        #expect(DayScenario(tasks: [once]).build().timeline.isEmpty)
    }

    /// Twice closes the day of a habit with three reminders too: no block (and no bell) is left for the third.
    @Test func twiceTakesEveryBlockOfAHabitWithThreeReminders() {
        let today = LocalDate(TestCalendar.wednesday)
        let drops = makeHabit("Eye drops") { task in
            task.reminderTimes = [LocalTime("09:00"), LocalTime("14:00"), LocalTime("20:00")]
            task.marks = [today: .twice]
        }
        #expect(DayScenario(tasks: [drops]).build().timeline.isEmpty)
    }

    @Test func aTimedHabitIsOnTheTimelineEveryDayItOccurs() throws {
        let vitamins = makeHabit("Vitamins", time: "09:00") { $0.timeEstimate = 2 }
        let plan = DayScenario(tasks: [vitamins]).build(at: TestCalendar.context(TestCalendar.wednesday, "08:00"))
        let slot = try #require(plan.slot("Vitamins"))
        #expect((clockTime(slot.start), clockTime(slot.end)) == ("09:00", "09:02"))
        #expect(plan.poolNames.isEmpty)
    }

    @Test func anEmptyEstimateGivesTheDefaultBlockLength() throws {
        let task = makeTask("No estimate") { $0.due = TaskDue("2026-10-21T11:00") }
        let slot = try #require(DayScenario(tasks: [task]).build().slot("No estimate"))
        #expect(slot.end.timeIntervalSince(slot.start) == Double(TestConfig.rules.day.defaultEstimateMinutes) * 60)
    }


    // MARK: - Events, reminders and greying out

    @Test func eventsAndRemindersOfTodayAreOnTheTimelineInTimeOrder() {
        let morning = makeEvent("Standup", from: "10:00", to: "10:15")
        let allDay = makeEvent("Holiday", from: "00:00", to: "23:59", allDay: true)
        let otherDay = makeEvent("Thursday sync", day: "2026-10-22", from: "10:00", to: "11:00")
        let reminder = makeReminder("Take the laundry out", at: "15:00")
        let tomorrowReminder = makeReminder("Tomorrow thing", day: "2026-10-22", at: "15:00")
        let plan = DayScenario(tasks: [], events: [call, otherDay, allDay, morning], reminders: [tomorrowReminder, reminder]).build()
        let titles = plan.timeline.map { slot -> String in
            switch slot.content {
            case .event(let event): return event.title
            case .reminder(let reminder): return reminder.title
            case .task(let item): return item.id
            }
        }
        #expect(titles == ["Standup", "Take the laundry out", "Call with dad"])
        #expect(plan.timeline.map { clockTime($0.end) } == ["10:15", "15:15", "20:00"])
    }

}
