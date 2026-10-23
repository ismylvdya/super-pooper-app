import SwiftUI

/// For recurring tasks: the rule in words and today's mark (Done / Partially / Twice / none).
struct TaskRecurrenceSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.actions) private var actions
    let task: TaskNote
    let item: DayItem?

    var body: some View {
        PlateSection(header: "taskPage.todayMark.header", info: "info.taskPage.recurrence") {
            if let item {
                Picker("taskPage.todayMark", selection: markBinding(item)) {
                    Text("taskPage.mark.none").tag(HabitMark?.none)
                    ForEach(HabitMark.allCases, id: \.self) { mark in
                        Text(LocalizedStringKey(actions.definition(actionID(mark)).title)).tag(HabitMark?.some(mark))
                    }
                }
                .pickerStyle(.segmented)
                if !item.isDone {
                    Button {
                        Task { await model.perform(.skipToday, on: task.name) }
                    } label: {
                        Label(LocalizedStringKey(actions.definition(.skipToday).title), systemImage: actions.definition(.skipToday).icon)
                    }
                }
            } else {
                Text("taskPage.notToday").font(tokens.font(.hint)).foregroundStyle(tokens.color(.secondaryText))
            }
        }
    }

    private func actionID(_ mark: HabitMark) -> ActionID {
        switch mark {
        case .done: .done
        case .partial: .partial
        case .twice: .twice
        }
    }

    private func markBinding(_ item: DayItem) -> Binding<HabitMark?> {
        Binding(get: { item.state.mark },
                set: { mark in
                    Haptics.play(.light)
                    Task { await model.perform(mark.map(actionID) ?? .unmark, on: task.name) }
                })
    }
}

/// The note body, edited as plain text and saved shortly after typing stops.
struct TaskNoteSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let taskName: String
    @State private var text = ""
    @State private var loaded: String?
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        PlateSection(header: "taskPage.note", info: "info.taskPage.note") {
            TextEditor(text: $text)
                .font(tokens.font(.noteEditor))
                .frame(minHeight: 160)
                .scrollContentBackground(.hidden)
        }
        .task(id: taskName) {
            let body = await model.body(of: taskName) ?? ""
            loaded = body
            text = body
        }
        .onChange(of: text) { _, value in
            guard let loaded, value != loaded else { return }
            saveTask?.cancel()
            saveTask = Task {
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                await model.setBody(value, of: taskName)
                self.loaded = value
            }
        }
        .onDisappear {
            guard let loaded, text != loaded else { return }
            let value = text
            Task { await model.setBody(value, of: taskName) }
        }
    }
}
