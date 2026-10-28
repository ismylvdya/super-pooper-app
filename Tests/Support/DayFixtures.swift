import Foundation
@testable import SuperPooperApp

/// Fixed time zone and calendar for every test: the user lives in Europe/Belgrade.
/// The reference week is Monday 2026-10-19 … Sunday 2026-10-25; most tests use Wednesday 2026-10-21.
enum TestCalendar {
    static let timeZone: TimeZone = {
        guard let zone = TimeZone(identifier: "Europe/Belgrade") else { preconditionFailure("No Europe/Belgrade") }
        return zone
    }()

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    /// Logical days with the default day boundary from `defaults.json`.
    static let days = DayBoundary(calendar: calendar, boundary: TestConfig.defaults.day.boundary)

    static let wednesday = "2026-10-21"

    /// Wall-clock `time` (`HH:mm`) on `day` (`YYYY-MM-DD`) in Belgrade.
    static func date(_ day: String, _ time: String = "00:00") -> Date {
        LocalDate(day).startDate(in: calendar, offset: LocalTime(time))
    }

    /// A day context with the default day boundary and energy hour from `defaults.json`.
    static func context(_ day: String = wednesday, _ time: String = "13:25") -> DayContext {
        DayContext(now: date(day, time), calendar: calendar,
                   boundary: TestConfig.defaults.day.boundary, energyHour: TestConfig.defaults.day.energyHour)
    }
}

extension LocalDate {
    /// `YYYY-MM-DD` that must be valid (test literals only).
    init(_ iso: String) {
        guard let value = LocalDate(isoString: iso) else { preconditionFailure("Invalid test date \(iso)") }
        self = value
    }
}

extension LocalTime {
    /// `HH:mm` that must be valid (test literals only).
    init(_ text: String) {
        guard let value = LocalTime(string: text) else { preconditionFailure("Invalid test time \(text)") }
        self = value
    }
}

extension TaskDue {
    /// `YYYY-MM-DD` or `YYYY-MM-DDTHH:mm` that must be valid (test literals only).
    init(_ raw: String) {
        guard let value = TaskDue(rawValue: raw) else { preconditionFailure("Invalid test due \(raw)") }
        self = value
    }
}

/// A regular task in `TaskNotes/Tasks`; `configure` sets the fields a test cares about.
func makeTask(_ name: String, status: TaskStatus = .thisWeek, created: String = "2026-10-10",
              _ configure: (inout TaskNote) -> Void = { _ in }) -> TaskNote {
    var task = TaskNote(name: name, relativePath: "TaskNotes/Tasks/\(name).md", status: status)
    task.dateCreated = TestCalendar.date(created, "09:00")
    configure(&task)
    return task
}

/// A recurring task (habit). `time` goes into `due`, as TaskNotes stores the time of day of a habit.
func makeHabit(_ name: String, rule: String = "DTSTART:20260901;FREQ=DAILY", time: String? = nil,
               status: TaskStatus = .halfYear, _ configure: (inout TaskNote) -> Void = { _ in }) -> TaskNote {
    makeTask(name, status: status, created: "2026-09-01") { task in
        task.recurrenceRaw = rule
        if case .success(let parsed) = RecurrenceRule.parse(rule) { task.recurrence = parsed }
        if let time { task.due = TaskDue("2026-09-01T\(time)") }
        configure(&task)
    }
}

func makeEvent(_ title: String, day: String = TestCalendar.wednesday, from start: String, to end: String,
               id: String? = nil, allDay: Bool = false) -> CalendarEvent {
    CalendarEvent(eventIdentifier: id ?? "ek-\(title)", title: title,
                  start: TestCalendar.date(day, start), end: TestCalendar.date(day, end), isAllDay: allDay,
                  calendarID: "cal-anchors", calendarTitle: "Anchors", colorHex: "#FF3B30")
}

func makeReminder(_ title: String, day: String = TestCalendar.wednesday, at time: String,
                  completed: Bool = false) -> ReminderItem {
    ReminderItem(id: "rem-\(title)", title: title, due: TestCalendar.date(day, time), listID: "list-remember",
                 listTitle: "Remember", colorHex: "#FF9500", isCompleted: completed)
}

/// A link from a task to `event`, as the app or the Claude skill would write it.
func eventLink(to event: CalendarEvent, identifier: String? = nil) -> EventLink {
    EventLink(eventIdentifier: identifier ?? event.eventIdentifier, title: event.title, start: event.start)
}

/// Inputs of one day, built with the real rules and sort order from the configs.
struct DayScenario {
    var tasks: [TaskNote]
    var events: [CalendarEvent] = []
    var reminders: [ReminderItem] = []
    var skipped: Set<String> = []
    var manualOrder: [String]?
    var routines = HabitRoutines()
    var postponed: Set<String> = []
    var eventsKnown = true

    func build(at context: DayContext = TestCalendar.context()) -> DayPlan {
        var inputs = DayInputs(tasks: tasks, events: events, reminders: reminders, skipped: skipped, manualOrder: manualOrder,
                               routines: routines, postponed: postponed)
        inputs.eventsKnown = eventsKnown
        return DayBuilder(rules: TestConfig.rules.day, sortCriteria: TestConfig.sort.pool).build(inputs, context: context)
    }
}

extension DayPlan {
    var poolNames: [String] { pool.map(\.id) }

    var timelineTaskNames: [String] {
        timeline.compactMap { slot in
            if case .task(let item) = slot.content { return item.id }
            return nil
        }
    }

    var dayNames: Set<String> { Set(poolNames + timelineTaskNames) }

    func slot(_ name: String) -> TimelineSlot? {
        timeline.first { slot in
            if case .task(let item) = slot.content { return item.id == name }
            return false
        }
    }

    func eventSlot(_ title: String) -> TimelineSlot? {
        timeline.first { slot in
            if case .event(let event) = slot.content { return event.title == title }
            return false
        }
    }

    func problems(of name: String) -> [TaskProblem] {
        problems.filter { $0.taskName == name }.map(\.problem)
    }
}

/// Wall-clock `HH:mm` of a date in Belgrade, for readable timeline assertions.
func clockTime(_ date: Date) -> String {
    let parts = TestCalendar.calendar.dateComponents([.hour, .minute], from: date)
    return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
}
