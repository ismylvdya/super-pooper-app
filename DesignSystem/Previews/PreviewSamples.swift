#if DEBUG
import Foundation

/// Sample data for SwiftUI previews: a small day built with the real domain logic.
enum PreviewSamples {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        return calendar
    }

    static var context: DayContext {
        let today = LocalDate(Date(), in: calendar)
        return DayContext(now: today.startDate(in: calendar, offset: LocalTime(hour: 11, minute: 30) ?? .midnight),
                          calendar: calendar, boundary: LocalTime(hour: 4, minute: 0) ?? .midnight,
                          energyHour: LocalTime(hour: 14, minute: 0) ?? .midnight)
    }

    static var tasks: [TaskNote] {
        let today = context.today
        let daily = RecurrenceRule.parse("DTSTART:\(today.adding(days: -20).isoString.replacingOccurrences(of: "-", with: ""));FREQ=DAILY")
        var water = TaskNote(name: "Выпить воды 💧", relativePath: "TaskNotes/Tasks/water.md", status: .halfYear)
        water.recurrenceRaw = "FREQ=DAILY"
        water.recurrence = try? daily.get()
        water.completeInstances = [today.adding(days: -2), today.adding(days: -1)]
        water.partialInstances = [today.adding(days: -2)]
        water.timeEstimate = 2
        var vitamins = water
        vitamins.name = "Витамины 💊"
        vitamins.relativePath = "TaskNotes/Tasks/vitamins.md"
        vitamins.due = TaskDue(day: today.adding(days: -20), time: LocalTime(hour: 9, minute: 0))
        var bank = TaskNote(name: "Позвонить в банк", relativePath: "TaskNotes/Tasks/bank.md", status: .thisWeek)
        bank.isHighPriority = true
        bank.needEnergy = true
        var report = TaskNote(name: "Сдать отчёт", relativePath: "TaskNotes/Tasks/report.md", status: .thisWeek)
        report.due = TaskDue(day: today.adding(days: 2))
        report.timeEstimate = 60
        report.pleasant = false
        var shelf = TaskNote(name: "Повесить полку", relativePath: "TaskNotes/Tasks/shelf.md", status: .thisWeek)
        shelf.previousTasks = ["Позвонить в банк"]
        var parcel = TaskNote(name: "Забрать посылку", relativePath: "TaskNotes/Tasks/parcel.md", status: .thisWeek)
        parcel.due = TaskDue(day: today, time: LocalTime(hour: 16, minute: 0))
        parcel.timeEstimate = 60
        var questions = TaskNote(name: "Подготовить вопросы", relativePath: "TaskNotes/Tasks/questions.md", status: .thisWeek)
        questions.nextEvent = EventLink(eventIdentifier: "call", title: "Call with dad", start: callStart)
        return [water, vitamins, bank, report, shelf, parcel, questions]
    }

    static var callStart: Date { context.date(context.today, LocalTime(hour: 19, minute: 0) ?? .midnight) }

    static var events: [CalendarEvent] {
        let today = context.today
        func event(_ id: String, _ title: String, _ start: Int, _ end: Int) -> CalendarEvent {
            CalendarEvent(eventIdentifier: id, title: title,
                          start: context.date(today, LocalTime(hour: start, minute: 0) ?? .midnight),
                          end: context.date(today, LocalTime(hour: end, minute: 0) ?? .midnight),
                          isAllDay: false, calendarID: "demo", calendarTitle: "Demo", colorHex: "#30B0C7")
        }
        return [event("sync", "Morning sync", 10, 11), event("call", "Call with dad", 19, 20)]
    }

    static var reminders: [ReminderItem] {
        [ReminderItem(id: "parcel", title: "Pick up the parcel",
                      due: context.date(context.today, LocalTime(hour: 15, minute: 0) ?? .midnight),
                      listID: "list", listTitle: "Remember", colorHex: "#FF9500", isCompleted: false)]
    }

    static var plan: DayPlan {
        let rules = DayRules(defaultEstimateMinutes: 15, reminderMinutes: 15, autoPromoteFrom: [])
        let inputs = DayInputs(tasks: tasks, events: events, reminders: reminders, skipped: [], manualOrder: nil)
        return DayBuilder(rules: rules, sortCriteria: PoolSortCriterion.allCases).build(inputs, context: context)
    }
}
#endif
