import SwiftUI

/// What a search across all task notes (by name) finds and, from Today, the calendar events the app has loaded.
/// A task opens its page (a swipe to the right is Done, to the left Delete, as in its list); an event opens Calendar on
/// its day.
struct TaskSearchResults: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.openURL) private var openURL
    /// With events, or task notes only.
    let withEvents: Bool
    let query: String
    @State private var pendingAction: PendingAction?

    var body: some View {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tasks = SearchMatcher.tasks(model.tasks, matching: text)
        let events = !withEvents ? [] : SearchMatcher.events(model.events, matching: text)
        List {
            if text.isEmpty {
                Text(withEvents ? "search.hint" : "search.hint.tasks").foregroundStyle(tokens.color(.secondaryText)).listRowBackground(Color.clear)
            } else if tasks.isEmpty, events.isEmpty {
                Text("search.empty").foregroundStyle(tokens.color(.secondaryText)).listRowBackground(Color.clear)
            }
            if !tasks.isEmpty {
                Section("search.tasks") {
                    ForEach(tasks) { task in
                        Button { router.open(.task(task.name)) } label: {
                            HStack(spacing: tokens.space(.iconTextGap)) {
                                TaggedTaskName(name: task.name)
                                Spacer()
                                Text(StatusText.title(task.status)).secondaryText()
                            }
                        }
                        .listRowBackground(tokens.color(.plateBackground))
                        .actionSwipes(.row(of: task), item: item(task), isToday: false) { handler.handle($0, taskName: task.name) }
                    }
                }
            }
            if !events.isEmpty {
                Section("search.events") {
                    ForEach(events) { event in
                        Button { open(event) } label: {
                            HStack(spacing: tokens.space(.iconTextGap)) {
                                SourceDot(hex: event.colorHex)
                                Text(event.title).foregroundStyle(tokens.color(.primaryText))
                                Spacer()
                                Text(DateText.format(event.start, Date.FormatStyle(date: .abbreviated, time: event.isAllDay ? .omitted : .shortened),
                                                     calendar: model.calendar))
                                    .secondaryText()
                            }
                        }
                        .listRowBackground(tokens.color(.plateBackground))
                    }
                }
            }
        }
        .appList()
        .actionConfirmation($pendingAction) { handler.run($0) }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }

    /// A habit is judged by today's mark, a task by its status.
    private func item(_ task: TaskItem) -> DayItem {
        task.isHabit ? DayItem(habit: task, on: model.context().today) : DayItem(listed: task)
    }

    private func open(_ event: CalendarEvent) {
        if let url = model.config.rules.eventLinks.calendarURL(at: event.start) { openURL(url) }
    }
}
