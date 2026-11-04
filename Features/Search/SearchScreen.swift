import SwiftUI

/// Search across all TaskNotes (by name) and, from Today, the calendar events the app has loaded.
/// A task opens its page (a swipe to the right is Done, to the left Delete, as in its list); an event opens Calendar on
/// its day.
struct SearchScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.openURL) private var openURL
    let scope: SearchScope
    @State private var query = ""
    @State private var pendingAction: PendingAction?
    @FocusState private var isFocused: Bool
    /// The field's X closes the search: back to the page it was opened from.
    @State private var isPresented = true

    var body: some View {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tasks = SearchMatcher.tasks(model.tasks, matching: text)
        let events = scope == .tasks ? [] : SearchMatcher.events(model.events, matching: text)
        List {
            if text.isEmpty {
                Text(scope == .tasks ? "search.hint.tasks" : "search.hint").foregroundStyle(tokens.color(.secondaryText)).listRowBackground(Color.clear)
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
        .navigationTitle(Text("search.title"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, isPresented: $isPresented, placement: .navigationBarDrawer(displayMode: .always), prompt: Text(scope == .tasks ? "search.prompt.tasks" : "search.prompt"))
        .searchFocused($isFocused)
        .onAppear { isFocused = true }
        .onChange(of: isPresented) { _, isOn in
            if !isOn, case .search = router.path.last { router.path.removeLast() }
        }
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
