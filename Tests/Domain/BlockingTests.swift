import Foundation
import Testing
@testable import SuperPooper

/// Blocking (`<day_logic>` "Блокировка", `<habits>` "Рутина"). Wednesday 2026-10-21, 13:25.
@Suite("Blocking")
struct BlockingTests {
    @Test func anUnfinishedPredecessorBlocks() throws {
        let plan = DayScenario(tasks: [makeTask("Find screwdriver"), assemble]).build()
        let item = try #require(plan.item(named: "Assemble wardrobe"))
        #expect(item.isBlocked)
        #expect(item.blockers == [.task("Find screwdriver")])
        #expect(plan.item(named: "Find screwdriver")?.isBlocked == false)
    }

    @Test(arguments: [LocalDate("2026-10-21"), LocalDate("2026-10-12")])
    func aDonePredecessorDoesNotBlockEvenWhenItIsNoLongerInTheDay(completed: LocalDate) {
        let found = makeTask("Find screwdriver", status: .done) { $0.completedDate = completed }
        let plan = DayScenario(tasks: [found, assemble]).build()
        #expect(plan.item(named: "Assemble wardrobe")?.blockers == [])
    }

    @Test func aPredecessorThatIsNotInTheDayStillBlocksUntilDone() {
        let later = makeTask("Find screwdriver", status: .halfYear)
        #expect(DayScenario(tasks: [later, assemble]).build().item(named: "Assemble wardrobe")?.isBlocked == true)
    }

    @Test func aMissingLinkedTaskDoesNotBlockButIsAProblem() {
        let task = makeTask("Linked to nothing") { $0.previousTasks = ["Несуществующая задача"] }
        let plan = DayScenario(tasks: [task]).build()
        #expect(plan.item(named: "Linked to nothing")?.isBlocked == false)
        #expect(plan.problems(of: "Linked to nothing") == [.linkedTaskNotFound("Несуществующая задача")])
    }

    @Test func aDoneTaskLeavesTheDayInsteadOfShowingBlocked() {
        let done = assemble.applying([.status(.done), .completedDate(LocalDate("2026-10-21"))])
        #expect(DayScenario(tasks: [makeTask("Find screwdriver"), done]).build().item(named: "Assemble wardrobe") == nil)
    }

    // MARK: - Recurring predecessors

    @Test func aRecurringPredecessorBlocksUntilTodayIsMarked() {
        let stretch = makeHabit("Stretch")
        let shower = makeHabit("Shower") { $0.previousTasks = ["Stretch"] }
        #expect(DayScenario(tasks: [stretch, shower]).build().item(named: "Shower")?.isBlocked == true)

        for mark in HabitMark.allCases {
            let marked = stretch.applying([.markInstance(day: LocalDate("2026-10-21"), mark: mark)])
            #expect(DayScenario(tasks: [marked, shower]).build().item(named: "Shower")?.isBlocked == false, "\(mark)")
        }
    }

    @Test func aMarkFromAnotherDayDoesNotUnblock() {
        let stretch = makeHabit("Stretch") { $0.completeInstances = [LocalDate("2026-10-20")] }
        let shower = makeHabit("Shower") { $0.previousTasks = ["Stretch"] }
        #expect(DayScenario(tasks: [stretch, shower]).build().item(named: "Shower")?.isBlocked == true)
    }

    @Test func aSkippedRecurringPredecessorDoesNotBlock() {
        let stretch = makeHabit("Stretch")
        let shower = makeHabit("Shower") { $0.previousTasks = ["Stretch"] }
        let plan = DayScenario(tasks: [stretch, shower], skipped: ["Stretch"]).build()
        #expect(plan.dayNames == ["Shower"])
        #expect(plan.item(named: "Shower")?.isBlocked == false)
    }

    @Test func aRecurringPredecessorWithoutAnInstanceTodayDoesNotBlock() {
        let laundry = makeHabit("Laundry", rule: "DTSTART:20260905;FREQ=WEEKLY;BYDAY=SA")
        let ironing = makeTask("Iron shirts") { $0.previousTasks = ["Laundry"] }
        let scenario = DayScenario(tasks: [laundry, ironing])
        #expect(scenario.build().item(named: "Iron shirts")?.isBlocked == false)
        #expect(scenario.build(at: TestCalendar.context("2026-10-24", "10:00")).item(named: "Iron shirts")?.isBlocked == true)
    }

    @Test func recurringStatusDoesNotMatterForBlocking() {
        let stretch = makeHabit("Stretch", status: .done)
        let shower = makeHabit("Shower") { $0.previousTasks = ["Stretch"] }
        #expect(DayScenario(tasks: [stretch, shower]).build().item(named: "Shower")?.isBlocked == true)
    }

    // MARK: - Morning routine

    @Test func aMorningRoutineUnlocksStepByStep() {
        let workout = makeHabit("Утро — зарядка 🤸")
        let shower = makeHabit("Утро — душ 🚿") { $0.previousTasks = ["Утро — зарядка 🤸"] }
        let breakfast = makeHabit("Утро — завтрак 🥣") { $0.previousTasks = ["Утро — душ 🚿"] }
        var tasks = [breakfast, shower, workout]

        var plan = DayScenario(tasks: tasks).build()
        #expect(plan.poolNames == ["Утро — зарядка 🤸", "Утро — душ 🚿", "Утро — завтрак 🥣"])
        #expect(plan.pool.map(\.isBlocked) == [false, true, true])
        #expect(plan.item(named: "Утро — завтрак 🥣")?.blockers == [.task("Утро — душ 🚿")])

        tasks[2] = markedToday(workout)
        plan = DayScenario(tasks: tasks).build()
        #expect(plan.item(named: "Утро — душ 🚿")?.isBlocked == false)
        #expect(plan.item(named: "Утро — завтрак 🥣")?.isBlocked == true)

        tasks[1] = markedToday(shower)
        plan = DayScenario(tasks: tasks).build()
        #expect(plan.item(named: "Утро — завтрак 🥣")?.isBlocked == false)
        #expect(plan.poolNames == ["Утро — завтрак 🥣"])
    }

    // MARK: - Events and cycles

    @Test func previousEventBlocksUntilTheEventEnds() throws {
        let call = makeEvent("Call with dad", from: "19:00", to: "20:00")
        let notes = makeTask("Write down the results") { $0.previousEvent = eventLink(to: call) }
        let scenario = DayScenario(tasks: [notes], events: [call])
        for time in ["13:25", "19:30", "19:59"] {
            let item = try #require(scenario.build(at: TestCalendar.context(TestCalendar.wednesday, time)).item(named: "Write down the results"))
            #expect(item.blockers == [.event(title: "Call with dad", end: call.end)], "\(time)")
        }
        #expect(scenario.build(at: TestCalendar.context(TestCalendar.wednesday, "20:00")).item(named: "Write down the results")?.isBlocked == false)
    }

    @Test func nextEventDoesNotBlock() {
        let call = makeEvent("Call with dad", from: "19:00", to: "20:00")
        let questions = makeTask("Prepare questions") { $0.nextEvent = eventLink(to: call) }
        #expect(DayScenario(tasks: [questions], events: [call]).build().item(named: "Prepare questions")?.isBlocked == false)
    }

    @Test(.timeLimit(.minutes(1)))
    func cyclesAreBrokenAndReported() throws {
        let a = makeTask("Цикл А") { $0.previousTasks = ["Цикл Б"] }
        let b = makeTask("Цикл Б") { $0.previousTasks = ["Цикл В"] }
        let c = makeTask("Цикл В") { $0.previousTasks = ["Цикл А"] }
        let outside = makeTask("After the cycle") { $0.previousTasks = ["Цикл А"] }
        let plan = DayScenario(tasks: [a, b, c, outside]).build()

        #expect(Set(plan.poolNames) == ["Цикл А", "Цикл Б", "Цикл В", "After the cycle"])
        for name in ["Цикл А", "Цикл Б", "Цикл В"] {
            #expect(plan.problems(of: name) == [.dependencyCycle], "\(name)")
        }
        #expect(plan.problems(of: "After the cycle").isEmpty)
        #expect(plan.pool.filter { !$0.isBlocked }.count == 1)
        let order = plan.poolNames
        for item in plan.pool {
            for case .task(let predecessor) in item.blockers {
                #expect(try #require(order.firstIndex(of: predecessor)) < (try #require(order.firstIndex(of: item.id))))
            }
        }
    }

    @Test func aTaskLinkedToItselfIsACycleThatDoesNotBlock() throws {
        let loop = makeTask("Loop") { $0.previousTasks = ["Loop"] }
        let plan = DayScenario(tasks: [loop]).build()
        let item = try #require(plan.item(named: "Loop"))
        #expect(!item.isBlocked)
        #expect(plan.problems(of: "Loop") == [.dependencyCycle])
    }

    // MARK: - Helpers

    private var assemble: TaskNote { makeTask("Assemble wardrobe") { $0.previousTasks = ["Find screwdriver"] } }

    private func markedToday(_ habit: TaskNote) -> TaskNote {
        habit.applying([.markInstance(day: LocalDate("2026-10-21"), mark: .done)])
    }
}
