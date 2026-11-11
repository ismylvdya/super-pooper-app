import SwiftUI

/// What a search of notes found (`SearchSections`) and, from Today, the calendar events the app has loaded: the same rows
/// under their groups' titles wherever notes are searched. A note opens its page (a swipe to the right is Done, to the
/// left Delete, as in its list); an event opens Calendar on its day.
struct NoteSearchResults: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.openURL) private var openURL
    let sections: [SearchSection]
    var events: [CalendarEvent] = []
    @State private var pendingAction: PendingAction?

    var body: some View {
        let shown = Set(sections.flatMap(\.notes).map(\.name.noteName))
        List {
            if sections.isEmpty, events.isEmpty {
                Text("search.empty").foregroundStyle(tokens.color(.secondaryText)).listRowBackground(Color.clear)
            }
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                Section {
                    ForEach(section.notes) { task in
                        Button { router.open(.task(task.name)) } label: {
                            HStack(spacing: tokens.space(.iconTextGap)) {
                                TaggedTaskName(name: task.name, parent: ShownParent.parent(of: task, shown: shown))
                                Spacer()
                                Text(StatusText.title(task.status)).secondaryText()
                            }
                        }
                        .listRowBackground(tokens.color(.plateBackground))
                        .actionSwipes(.row(of: task), item: item(task), isToday: false) { handler.handle($0, taskName: task.name) }
                    }
                } header: {
                    title(section.title)
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

    private func title(_ title: SearchSection.Title) -> Text {
        switch title {
        case .key(let key): Text(LocalizedStringKey(key))
        case .text(let text): Text(verbatim: text)
        }
    }

    private func open(_ event: CalendarEvent) {
        if let url = model.config.rules.eventLinks.calendarURL(at: event.start) { openURL(url) }
    }
}
