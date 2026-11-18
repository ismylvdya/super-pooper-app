import ListEngineChumbulev
import SwiftUI

/// What a search of notes found (`SearchSections`) and, from Today, the calendar events the app has loaded, as a list of
/// the list engine: the same rows under their groups' titles wherever notes are searched. Before a name its mark: a
/// task's (the tasks' emoji), a habit's (the habit symbol in its color), an event's (its calendar's dot). A note opens its
/// page; its menu is the pool's; a task swipes to the right to Done and to the left to Delete, a habit or a repeatable
/// task only to Done. An event opens Calendar on its day; its menu and a swipe to the left delete it, once confirmed.
/// Nothing is carried.
struct NoteSearchResults: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.actions) private var registry
    @Environment(\.openURL) private var openURL
    let sections: [SearchSection]
    var events: [CalendarEvent] = []
    @State private var pendingAction: PendingAction?
    @State private var eventToDelete: CalendarEvent?

    var body: some View {
        ReorderableList(sections: .constant(rows), look: "lists", actions: menu, swipes: swipes,
                        features: [.menu, .swipes, .haptics, .dim], onTap: open,
                        footer: sections.isEmpty && events.isEmpty ? AnyView(empty) : nil) { row($0) }
            .ignoresSafeArea()
            .actionConfirmation($pendingAction) { handler.run($0) }
            .alert("event.delete.title", isPresented: Binding(presenting: $eventToDelete), presenting: eventToDelete) { event in
                Button("action.deleteEvent", role: .destructive) { Task { await model.deleteEvent(event) } }
                Button("common.cancel", role: .cancel) {}
            } message: { event in
                Text(L10n.format("event.delete.message", event.title))
            }
    }

    private var rows: [ListSection<SearchRow>] {
        let shown = Set(sections.flatMap(\.notes).map(\.name.noteName))
        var rows = sections.enumerated().map { index, section in
            ListSection(id: "notes.\(index)", title: title(section.title),
                        items: section.notes.map { SearchRow.note($0, parent: ShownParent.parent(of: $0, shown: shown)) })
        }
        if !events.isEmpty {
            rows.append(ListSection(id: "events", title: L10n.string("search.events"), items: events.map(SearchRow.event)))
        }
        return rows
    }

    @ViewBuilder private func row(_ row: SearchRow) -> some View {
        switch row {
        case .note(let task, let parent):
            ListRowContent(title: task.name, chips: [detail(StatusText.title(task.status))], icon: mark(of: task),
                           iconColor: task.isHabit ? ThemeColor(tokens.habitSymbolColor(task)) : nil, overline: parent)
        case .event(let event):
            ListRowContent(title: event.title,
                           chips: [detail(DateText.format(event.start, Date.FormatStyle(date: .abbreviated, time: event.isAllDay ? .omitted : .shortened),
                                                          calendar: model.calendar))],
                           icon: .symbol("circle.fill"), iconColor: ThemeColor(UIColor(Color(hex: event.colorHex))))
        }
    }

    /// The habit symbol for a habit or a repeatable task, the tasks' emoji for a task.
    private func mark(of task: TaskItem) -> ListIcon? {
        if task.isHabit { return .app(icons[.habit]) }
        return model.taskMark.map(ListIcon.emoji)
    }

    private func detail(_ text: String) -> ListChip {
        ListChip(kind: "detail", content: .text(text), color: ThemeColor(tokens.uiColor(.secondaryText)))
    }

    private func open(_ row: SearchRow) {
        switch row {
        case .note(let task, _): router.open(.task(task.name))
        case .event(let event):
            if let url = model.config.rules.eventLinks.calendarURL(at: event.start) { openURL(url) }
        }
    }

    private func menu(_ row: SearchRow) -> [ListAction] {
        switch row {
        case .note(let task, _):
            return engine.menu(.context(of: task), for: item(task), isToday: false)
        case .event(let event):
            let delete = registry.definition(.deleteEvent)
            return [ListAction(title: L10n.string(delete.title), icon: .app(delete.icon), tone: .destructive) { eventToDelete = event }]
        }
    }

    /// A task: to the right Done, to the left Delete; a habit or a repeatable task: only Done; an event: only Delete.
    private func swipes(_ row: SearchRow) -> ListSwipes {
        switch row {
        case .note(let task, _):
            let both = engine.swipes(.row(of: task), for: item(task), isToday: false)
            return task.isHabit ? ListSwipes(leading: both.leading) : both
        case .event(let event):
            let delete = registry.definition(.deleteEvent)
            return ListSwipes(trailing: ListSwipe(title: L10n.string(delete.title), icon: .app(delete.icon),
                                                  color: ThemeColor(tokens.uiColor(.destructive))) { eventToDelete = event })
        }
    }

    private var empty: some View {
        Text("search.empty").foregroundStyle(tokens.color(.secondaryText))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ListTheme.app.rows.sideInset)
    }

    /// A habit is judged by today's mark, a task by its status.
    private func item(_ task: TaskItem) -> DayItem {
        task.isHabit ? DayItem(habit: task, on: model.context().today) : DayItem(listed: task)
    }

    private func title(_ title: SearchSection.Title) -> String {
        switch title {
        case .key(let key): L10n.string(key)
        case .text(let text): text
        }
    }

    private var engine: EngineActions {
        EngineActions(model: model, tokens: tokens, registry: registry, icons: icons) { handler.handle($0, taskName: $1) }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }
}

/// A row of the search: a note (with its parent's name when the parent is not among the results), or an event.
enum SearchRow: Identifiable, Hashable {
    case note(TaskItem, parent: String?)
    case event(CalendarEvent)

    var id: String {
        switch self {
        case .note(let task, _): "note:" + task.name
        case .event(let event): "event:" + event.id
        }
    }
}
