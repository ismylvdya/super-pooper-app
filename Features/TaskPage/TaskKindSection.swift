import SwiftUI

/// The switch at the very top of the page: a one-off task or a repeating habit.
struct TaskKindSection: View {
    @Environment(AppModel.self) private var model
    let task: TaskNote

    var body: some View {
        PlateSection(header: "taskKind.header", info: "info.taskKind") {
            Picker("taskKind.header", selection: Binding(
                get: { task.isHabit ? TaskKind.habit : .task },
                set: { kind in
                    let changes = kind.changes(for: task, today: model.context().today)
                    guard !changes.isEmpty else { return }
                    Haptics.play(.light)
                    Task { await model.update(task.name, changes) }
                }
            )) {
                Text("taskKind.task").tag(TaskKind.task)
                Text("taskKind.habit").tag(TaskKind.habit)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("taskPage.kind")
        }
    }
}

/// A habit's reminders: none (any time of the day), one, or several (e.g. for "twice a day").
struct HabitRemindersSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons
    @Environment(\.tokens) private var tokens
    let task: TaskNote

    var body: some View {
        PlateSection(header: "taskPage.reminders", info: "info.taskPage.reminders", hint: times.isEmpty ? "taskPage.reminders.none" : nil) {
            ForEach(Array(times.enumerated()), id: \.offset) { index, time in
                PlateRow(icon: index == 0 ? .reminder : nil, title: "taskPage.reminders.time") {
                    DatePicker("taskPage.reminders.time", selection: binding(at: index), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Button { save(times.enumerated().filter { $0.offset != index }.map(\.element)) } label: {
                        Image(systemName: icons[.remove]).foregroundStyle(tokens.color(.problem))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("taskPage.reminders.remove"))
                }
            }
            Button { save(times + [nextTime]) } label: {
                Label("taskPage.reminders.add", systemImage: icons[.add])
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("taskPage.reminders.add")
        }
    }

    private var times: [LocalTime] { task.habitTimes }

    /// Four hours after the last reminder, or 09:00 for the first one.
    private var nextTime: LocalTime {
        guard let last = times.last else { return LocalTime(hour: 9, minute: 0)! }
        return LocalTime(minutesSinceMidnight: last.hour * 60 + last.minute + 240)
    }

    private func binding(at index: Int) -> Binding<Date> {
        Binding(
            get: { model.context().today.startDate(in: model.calendar, offset: times[index]) },
            set: { date in
                let parts = model.calendar.dateComponents([.hour, .minute], from: date)
                var updated = times
                updated[index] = LocalTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0) ?? times[index]
                save(updated)
            }
        )
    }

    private func save(_ updated: [LocalTime]) {
        Task { await model.update(task.name, [.reminderTimes(updated), .due(nil)]) }
    }
}
