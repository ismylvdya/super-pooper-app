import SwiftUI

/// Search across all TaskNotes (by name) and the calendar events the app has loaded.
/// A task opens its page; an event opens Calendar on its day.
struct SearchScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.openURL) private var openURL
    @State private var query = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tasks = SearchMatcher.tasks(model.tasks, matching: text)
        let events = SearchMatcher.events(model.events, matching: text)
        List {
            if text.isEmpty {
                Text("search.hint").foregroundStyle(tokens.color(.secondaryText)).listRowBackground(Color.clear)
            } else if tasks.isEmpty, events.isEmpty {
                Text("search.empty").foregroundStyle(tokens.color(.secondaryText)).listRowBackground(Color.clear)
            }
            if !tasks.isEmpty {
                Section("search.tasks") {
                    ForEach(tasks) { task in
                        Button { router.open(.task(task.name)) } label: {
                            HStack(spacing: tokens.space(.iconTextGap)) {
                                if let emoji = TagEmoji.leading(of: model.settings.vault.taskTag) {
                                    Text(verbatim: emoji).font(tokens.font(.caption))
                                }
                                Text(task.name).foregroundStyle(tokens.color(.primaryText))
                                Spacer()
                                Text(StatusText.title(task.status)).font(tokens.font(.caption)).foregroundStyle(tokens.color(.secondaryText))
                            }
                        }
                        .listRowBackground(tokens.color(.plateBackground))
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
                                Text(event.start.formatted(date: .abbreviated, time: event.isAllDay ? .omitted : .shortened))
                                    .font(tokens.font(.caption)).foregroundStyle(tokens.color(.secondaryText))
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
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("search.prompt"))
        .searchFocused($isFocused)
        .onAppear { isFocused = true }
    }

    private func open(_ event: CalendarEvent) {
        if let url = model.config.rules.eventLinks.calendarURL(at: event.start) { openURL(url) }
    }
}
