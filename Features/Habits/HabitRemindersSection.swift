import SwiftUI

/// A habit's reminders: none (any time of the day), one, or several (e.g. for "twice a day").
struct HabitRemindersSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons
    @Environment(\.rules) private var rules
    let editor: TaskEditor

    private var task: TaskItem { editor.task }

    var body: some View {
        PlateSection(header: "taskPage.reminders", info: "info.taskPage.reminders", hint: times.isEmpty ? "taskPage.reminders.none" : nil) {
            ForEach(Array(times.enumerated()), id: \.offset) { index, time in
                PlateRow(icon: index == 0 ? .reminder : nil, title: "taskPage.reminders.time") {
                    TimeField("taskPage.reminders.time", time: binding(at: index), on: model.context().today)
                        .labelsHidden()
                    RemoveButton(label: "taskPage.reminders.remove") {
                        save(times.enumerated().filter { $0.offset != index }.map(\.element))
                    }
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

    /// A while after the last reminder, or the default time for the first one (`rules.json` → `editing`).
    private var nextTime: LocalTime {
        guard let last = times.last else { return rules.editing.defaultTime }
        return LocalTime(minutesSinceMidnight: last.minutesSinceMidnight + rules.editing.nextReminderGapMinutes)
    }

    private func binding(at index: Int) -> Binding<LocalTime> {
        Binding(
            get: { times[index] },
            set: { time in
                var updated = times
                updated[index] = time
                save(updated)
            }
        )
    }

    private func save(_ updated: [LocalTime]) {
        editor.edit { habit in HabitReminderTimes.changes(setting: updated, on: habit) }
    }
}
