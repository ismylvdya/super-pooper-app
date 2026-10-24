import Foundation
import Testing
@testable import SuperPooper

/// The whole day built from the test vault, as the user would see it on Wednesday 2026-10-21.
/// Calendar: a 10:00 standup, "Call with dad" 19:00–20:00 (the notes link it by title and time),
/// a reminder at 15:00.
@Suite("Day built from the test vault")
struct FixtureDayPlanTests {
    private let call = makeEvent("Call with dad", from: "19:00", to: "20:00", id: "EK-call-with-dad")
    private let standup = makeEvent("Standup", from: "10:00", to: "10:15")
    private let reminder = makeReminder("Take the laundry out", at: "15:00")

    @Test func lunchtimePoolIsSortedByTheSpecCriteria() async throws {
        let plan = try await build(at: "13:25")
        #expect(plan.poolNames == [
            // The morning routine first, all day long.
            "Выпить воды 💧", "Утро — зарядка 🤸", "Утро — душ 🚿", "Утро — завтрак 🥣",
            "Неизвестное правило", "Полить цветы 🌱", "Медитация 🧘",
            "Оплатить интернет", "Позвонить в банк", "Сдать отчёт", "Разобрать почту", "Помыть окна",
            "Сходить к стоматологу", "Купить батарейки 🔋", "Длинная заметка с незнакомыми ключами", "Найти отвёртку",
            "Записать идеи", "Связь без скобок", "Связь на несуществующую", "Цикл Б", "Цикл А", "Собрать шкаф",
            "Повесить зеркало", "Посмотреть сериал 🍿", "Купить молоко",
        ])
        #expect(plan.pool.last?.isDone == true)
    }

    @Test func afterTheEnergyHourEnergyTasksGoDown() async throws {
        let plan = try await build(at: "15:30")
        let names = plan.poolNames
        let mail = try #require(names.firstIndex(of: "Разобрать почту"))
        let windows = try #require(names.firstIndex(of: "Помыть окна"))
        let dentist = try #require(names.firstIndex(of: "Сходить к стоматологу"))
        let series = try #require(names.firstIndex(of: "Посмотреть сериал 🍿"))
        #expect(dentist < mail && series < mail && mail < windows)
        #expect(names.prefix(4) == ["Выпить воды 💧", "Утро — зарядка 🤸", "Утро — душ 🚿", "Утро — завтрак 🥣"])
        #expect(names[7...9] == ["Оплатить интернет", "Позвонить в банк", "Сдать отчёт"])
    }

    @Test func hiddenTasksStayOutOfTheDay() async throws {
        let plan = try await build(at: "13:25")
        let hidden: Set<String> = ["Архивная задача", "Ждать ответа от арендодателя", "Выучить испанский", "Обновить резюме",
                                   "Старая сделанная задача", "Стирка 🧺"]
        #expect(plan.dayNames.isDisjoint(with: hidden))
        #expect(plan.dayNames.count == 30)
    }

    @Test func timelineHoldsTimedTasksChainsEventsAndReminders() async throws {
        let plan = try await build(at: "13:25")
        let rows = plan.timeline.map { slot -> String in
            let title: String
            switch slot.content {
            case .event(let event): title = "event \(event.title)"
            case .reminder(let reminder): title = "reminder \(reminder.title)"
            case .task(let item): title = item.id
            }
            return "\(clockTime(slot.start))–\(clockTime(slot.end)) \(title)\(slot.isPast ? " (past)" : "")"
        }
        #expect(rows == [
            "09:00–09:02 Витамины 💊",
            "10:00–10:15 event Standup (past)",
            "13:25–13:40 Подготовить вопросы папе",
            "13:40–13:55 Распечатать вопросы",
            "15:00–15:15 reminder Take the laundry out",
            "16:00–17:00 Забрать посылку на почте",
            "19:00–20:00 event Call with dad",
            "20:00–20:15 Записать итоги разговора",
        ])
        #expect(plan.problems.count == 4)
    }

    @Test func blockedItemsAreTheOnesWithUnfinishedPredecessorsOrARunningEvent() async throws {
        let plan = try await build(at: "13:25")
        let blocked = (plan.pool + plan.timeline.compactMap { slot in
            if case .task(let item) = slot.content { return item }
            return nil
        }).filter(\.isBlocked).map(\.id)
        #expect(Set(blocked) == ["Утро — душ 🚿", "Утро — завтрак 🥣", "Повесить зеркало", "Собрать шкаф", "Связь без скобок",
                                 "Цикл А", "Распечатать вопросы", "Записать итоги разговора"])
    }

    @Test func afterTheCallTheFollowUpStartsAtNowAndIsFree() async throws {
        let plan = try await build(at: "21:10")
        let notes = try #require(plan.slot("Записать итоги разговора"))
        #expect(clockTime(notes.start) == "21:10")
        #expect(plan.item(named: "Записать итоги разговора")?.isBlocked == false)
        #expect(plan.eventSlot("Call with dad")?.isPast == true)
    }

    @Test func weeklyAndEveryThirdDayHabitsFollowTheirRules() async throws {
        let scenario = DayScenario(tasks: try await VaultSandbox.make().scan().tasks)
        let thursday = scenario.build(at: TestCalendar.context("2026-10-22", "10:00")).dayNames
        let saturday = scenario.build(at: TestCalendar.context("2026-10-24", "10:00")).dayNames
        #expect(!thursday.contains("Стирка 🧺") && !thursday.contains("Полить цветы 🌱"))
        #expect(saturday.contains("Стирка 🧺") && saturday.contains("Полить цветы 🌱"))
    }

    @Test func onlyTheHalfYearTaskDueThisWeekIsPromoted() async throws {
        let tasks = try await VaultSandbox.make().scan().tasks
        let statuses = Set(TestConfig.rules.day.autoPromoteFrom.map(TestConfig.mapping.status(fromRaw:)))
        let promoted = AutoPromoter(promotableStatuses: statuses).candidates(in: tasks, context: TestCalendar.context())
        #expect(promoted.map(\.name) == ["Обновить резюме"])
    }

    private func build(at time: String) async throws -> DayPlan {
        let tasks = try await VaultSandbox.make().scan().tasks
        return DayScenario(tasks: tasks, events: [standup, call], reminders: [reminder])
            .build(at: TestCalendar.context(TestCalendar.wednesday, time))
    }
}
