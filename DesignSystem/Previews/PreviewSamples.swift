#if DEBUG
import Foundation

/// Sample data for SwiftUI previews: a small day at 11:30 today, built with the real domain logic, the app's calendar
/// and the default settings.
enum PreviewSamples {
    static var calendar: Calendar { AppCalendar.make() }

    static var context: DayContext {
        let today = LocalDate(SystemClock().now, in: calendar)
        let day = BundledConfig.settings.day
        return DayContext(now: today.startDate(in: calendar, offset: LocalTime(hour: 11, minute: 30) ?? .midnight),
                          calendar: calendar, boundary: day.boundary, energyHour: day.energyHour)
    }

    static var tasks: [TaskItem] {
        let today = context.today
        var water = TaskItem(id: TaskID("TaskNotes/Tasks/water.md"), name: "Выпить воды 💧", status: .halfYear)
        water.recurrence = RecurrenceDraft(start: today.adding(days: -20)).rule
        water.marks = [today.adding(days: -2): .partial, today.adding(days: -1): .done]
        water.timeEstimate = 2
        var vitamins = water
        vitamins.name = "Витамины 💊"
        vitamins.id = TaskID("TaskNotes/Tasks/vitamins.md")
        vitamins.due = TaskDue(day: today.adding(days: -20), time: LocalTime(hour: 9, minute: 0))
        var bank = TaskItem(id: TaskID("TaskNotes/Tasks/bank.md"), name: "Позвонить в банк", status: .thisWeek)
        bank.isHighPriority = true
        bank.feel = .needEnergy
        var report = TaskItem(id: TaskID("TaskNotes/Tasks/report.md"), name: "Сдать отчёт", status: .thisWeek)
        report.due = TaskDue(day: today.adding(days: 2))
        report.timeEstimate = 60
        report.feel = .needEnergy
        let shelf = TaskItem(id: TaskID("TaskNotes/Tasks/shelf.md"), name: "Повесить полку", status: .thisWeek)
        var parcel = TaskItem(id: TaskID("TaskNotes/Tasks/parcel.md"), name: "Забрать посылку", status: .thisWeek)
        parcel.due = TaskDue(day: today, time: LocalTime(hour: 16, minute: 0))
        parcel.timeEstimate = 60
        let questions = TaskItem(id: TaskID("TaskNotes/Tasks/questions.md"), name: "Подготовить вопросы", status: .thisWeek)
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
        let inputs = DayInputs(tasks: tasks, events: events, reminders: reminders, skipped: [], manualOrder: nil)
        return DayBuilder(rules: BundledConfig.rules.day, sortCriteria: PoolSortCriterion.allCases,
                          sections: BundledConfig.rules.pool.defaultSections).build(inputs, context: context)
    }
}
#endif
