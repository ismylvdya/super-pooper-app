import Foundation
import Testing
@testable import SuperPooper

/// Pool vs timeline (`<day_logic>` "Таймлайн", "Пул", "Расстановка на таймлайне").
/// Wednesday 2026-10-21; "Call with dad" is 19:00–20:00; "now" is 13:25 unless a test says otherwise.
@Suite("Day pool and timeline")
struct DayTimelineTests {
    private let call = makeEvent("Call with dad", from: "19:00", to: "20:00")

    // MARK: - Timed tasks

    @Test func aTaskDueTodayWithTimeIsOnTheTimelineAtItsTime() throws {
        let parcel = makeTask("Pick up parcel") { $0.due = TaskDue("2026-10-21T16:00"); $0.timeEstimate = 60 }
        let plan = DayScenario(tasks: [parcel]).build()
        let slot = try #require(plan.slot("Pick up parcel"))
        #expect(plan.poolNames.isEmpty)
        #expect((clockTime(slot.start), clockTime(slot.end)) == ("16:00", "17:00"))
        #expect(!slot.isPast)
    }

    @Test func dueWithoutTimeOrOnAnotherDayStaysInThePool() {
        let today = makeTask("Due today") { $0.due = TaskDue("2026-10-21") }
        let friday = makeTask("Friday at ten") { $0.due = TaskDue("2026-10-23T10:00") }
        let overdue = makeTask("Yesterday at ten") { $0.due = TaskDue("2026-10-20T10:00") }
        let plan = DayScenario(tasks: [today, friday, overdue]).build()
        #expect(Set(plan.poolNames) == ["Due today", "Friday at ten", "Yesterday at ten"])
        #expect(plan.timeline.isEmpty)
    }

    @Test func aTimedHabitIsOnTheTimelineEveryDayItOccurs() throws {
        let vitamins = makeHabit("Vitamins", time: "09:00") { $0.timeEstimate = 2 }
        let plan = DayScenario(tasks: [vitamins]).build()
        let slot = try #require(plan.slot("Vitamins"))
        #expect((clockTime(slot.start), clockTime(slot.end)) == ("09:00", "09:02"))
        #expect(plan.poolNames.isEmpty)
    }

    @Test func anEmptyEstimateGivesTheDefaultBlockLength() throws {
        let task = makeTask("No estimate") { $0.due = TaskDue("2026-10-21T11:00") }
        let slot = try #require(DayScenario(tasks: [task]).build().slot("No estimate"))
        #expect(slot.end.timeIntervalSince(slot.start) == Double(TestConfig.rules.day.defaultEstimateMinutes) * 60)
    }

    // MARK: - Chains tied to events

    @Test func nextEventChainsStartAtNowInLinkOrder() throws {
        let questions = makeTask("Prepare questions") { $0.nextEvent = eventLink(to: call) }
        let printing = makeTask("Print questions") { $0.previousTasks = ["Prepare questions"]; $0.timeEstimate = 2 }
        let plan = DayScenario(tasks: [printing, questions], events: [call]).build()
        let first = try #require(plan.slot("Prepare questions"))
        let second = try #require(plan.slot("Print questions"))
        #expect(plan.poolNames.isEmpty)
        #expect((clockTime(first.start), clockTime(first.end)) == ("13:25", "13:40"))
        #expect((clockTime(second.start), clockTime(second.end)) == ("13:40", "13:42"))
    }

    @Test func openChainsFollowNowDuringTheDay() throws {
        let questions = makeTask("Prepare questions") { $0.nextEvent = eventLink(to: call) }
        let plan = DayScenario(tasks: [questions], events: [call]).build(at: TestCalendar.context(TestCalendar.wednesday, "17:10"))
        #expect(try clockTime(#require(plan.slot("Prepare questions")).start) == "17:10")
    }

    @Test func previousEventChainsStartWhenTheEventEnds() throws {
        let notes = makeTask("Write down the results") { $0.previousEvent = eventLink(to: call) }
        let thanks = makeTask("Send thanks") { $0.previousTasks = ["Write down the results"]; $0.timeEstimate = 2 }
        let plan = DayScenario(tasks: [notes, thanks], events: [call]).build()
        #expect(try clockTime(#require(plan.slot("Write down the results")).start) == "20:00")
        #expect(try clockTime(#require(plan.slot("Send thanks")).start) == "20:15")
    }

    @Test func previousEventChainsStartAtNowOnceTheEventIsOver() throws {
        let notes = makeTask("Write down the results") { $0.previousEvent = eventLink(to: call) }
        let plan = DayScenario(tasks: [notes], events: [call]).build(at: TestCalendar.context(TestCalendar.wednesday, "21:40"))
        #expect(try clockTime(#require(plan.slot("Write down the results")).start) == "21:40")
    }

    @Test func indirectLinksReachTheTimelineThroughSeveralSteps() {
        let anchor = makeTask("Step 1") { $0.nextEvent = eventLink(to: call) }
        let second = makeTask("Step 2") { $0.previousTasks = ["Step 1"] }
        let third = makeTask("Step 3") { $0.previousTasks = ["Step 2"] }
        let plan = DayScenario(tasks: [third, second, anchor], events: [call]).build()
        #expect(plan.timelineTaskNames == ["Step 1", "Step 2", "Step 3"])
        #expect(plan.poolNames.isEmpty)
    }

    @Test func whatComesBeforeATaskThatIsBeforeAnEventIsOnTheTimelineToo() {
        let anchor = makeTask("Get a haircut") { $0.nextEvent = eventLink(to: call); $0.previousTasks = ["Buy shampoo"] }
        let earlier = makeTask("Buy shampoo")
        let plan = DayScenario(tasks: [anchor, earlier], events: [call]).build()
        #expect(plan.timelineTaskNames == ["Buy shampoo", "Get a haircut"])
        #expect(plan.poolNames.isEmpty)
    }

    @Test func aPredecessorOfATaskAfterAnEventStaysInThePool() {
        let anchor = makeTask("Write notes") { $0.previousEvent = eventLink(to: call); $0.previousTasks = ["Find pen"] }
        let earlier = makeTask("Find pen")
        let plan = DayScenario(tasks: [anchor, earlier], events: [call]).build()
        #expect(plan.timelineTaskNames == ["Write notes"])
        #expect(plan.poolNames == ["Find pen"])
    }

    @Test func tasksLinkedOnlyToEachOtherStayInThePool() {
        let first = makeTask("Find screwdriver")
        let second = makeTask("Assemble wardrobe") { $0.previousTasks = ["Find screwdriver"] }
        let plan = DayScenario(tasks: [first, second], events: [call]).build()
        #expect(plan.poolNames == ["Find screwdriver", "Assemble wardrobe"])
        #expect(plan.timelineTaskNames.isEmpty)
    }

    @Test func aSuccessorOfATimedTaskStaysInThePool() {
        let timed = makeTask("At four") { $0.due = TaskDue("2026-10-21T16:00") }
        let after = makeTask("After four") { $0.previousTasks = ["At four"] }
        let plan = DayScenario(tasks: [timed, after]).build()
        #expect(plan.timelineTaskNames == ["At four"])
        #expect(plan.poolNames == ["After four"])
    }

    @Test func anEventOnAnotherDayKeepsTheTaskInThePoolWithoutAProblem() {
        let tomorrow = makeEvent("Dentist", day: "2026-10-22", from: "10:00", to: "11:00")
        let task = makeTask("Prepare for dentist") { $0.nextEvent = eventLink(to: tomorrow) }
        let plan = DayScenario(tasks: [task], events: [call, tomorrow]).build()
        #expect(plan.poolNames == ["Prepare for dentist"])
        #expect(plan.problems.isEmpty)
        #expect(plan.eventSlot("Dentist") == nil)
    }

    @Test func aMissingEventIsAProblemAndTheTaskStaysInThePool() {
        let gone = makeEvent("Cancelled meeting", from: "11:00", to: "12:00")
        let task = makeTask("Prepare slides") { $0.nextEvent = eventLink(to: gone) }
        let plan = DayScenario(tasks: [task], events: [call]).build()
        #expect(plan.poolNames == ["Prepare slides"])
        #expect(plan.problems(of: "Prepare slides") == [.eventNotFound("Cancelled meeting")])
        #expect(plan.item(named: "Prepare slides")?.isBlocked == false)
    }

    @Test func eventsResolveByIdentifierEvenAfterARenameAndPickTodaysInstance() {
        let renamed = makeEvent("Call with Dad (moved)", from: "19:00", to: "20:00", id: "series-1")
        let yesterday = makeEvent("Call with Dad (moved)", day: "2026-10-20", from: "19:00", to: "20:00", id: "series-1")
        let stale = EventLink(eventIdentifier: "series-1", title: "Call with dad", start: TestCalendar.date("2026-10-21", "19:00"))
        let task = makeTask("Prepare questions") { $0.nextEvent = stale }
        let plan = DayScenario(tasks: [task], events: [yesterday, renamed]).build()
        #expect(plan.timelineTaskNames == ["Prepare questions"])
        #expect(plan.problems.isEmpty)
    }

    @Test func eventsResolveByTitleAndStartWhenTheIdentifierIsUnknown() {
        let task = makeTask("Prepare questions") { $0.nextEvent = eventLink(to: call, identifier: "fixture-event") }
        let plan = DayScenario(tasks: [task], events: [call]).build()
        #expect(plan.timelineTaskNames == ["Prepare questions"])
        #expect(plan.problems.isEmpty)
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

    @Test func onlyPastEventsAreGreyedOutWhileDoneEntriesLeave() throws {
        let morning = makeEvent("Standup", from: "10:00", to: "10:15")
        let doneTimed = makeHabit("Vitamins", time: "09:00") { $0.completeInstances = [LocalDate("2026-10-21")] }
        let openTimed = makeTask("Missed at noon") { $0.due = TaskDue("2026-10-21T12:00") }
        let doneChain = makeTask("Prepared", status: .done) { $0.completedDate = LocalDate("2026-10-21"); $0.nextEvent = eventLink(to: self.call) }
        let openChain = makeTask("To print") { $0.previousTasks = ["Prepared"] }
        let reminders = [makeReminder("Done reminder", at: "16:00", completed: true), makeReminder("Past reminder", at: "11:00")]
        let plan = DayScenario(tasks: [doneTimed, openTimed, doneChain, openChain], events: [morning, call], reminders: reminders).build()

        #expect(plan.eventSlot("Standup")?.isPast == true)
        #expect(plan.eventSlot("Call with dad")?.isPast == false)
        #expect(plan.slot("Vitamins") == nil)
        #expect(plan.slot("Prepared") == nil)
        #expect(plan.slot("Missed at noon")?.isPast == false)
        let open = try #require(plan.slot("To print"))
        #expect(!open.isPast && clockTime(open.start) == "13:25")
        let reminderSlots = plan.timeline.filter { if case .reminder = $0.content { return true } else { return false } }
        #expect(reminderSlots.count == 1 && !reminderSlots[0].isPast)
    }
}
