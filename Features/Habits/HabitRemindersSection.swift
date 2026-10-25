import SwiftUI

/// A habit's reminders: none (any time of the day), one, or several (e.g. for "twice a day").
struct HabitRemindersSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons
    @Environment(\.rules) private var rules
    let editor: TaskEditor

    private var task: TaskNote { editor.task }

    var body: some View {
        PlateSection(header: "taskPage.reminders", info: "info.taskPage.reminders", hint: times.isEmpty ? "taskPage.reminders.none" : nil) {
            ForEach(Array(times.enumerated()), id: \.offset) { index, time in
                PlateRow(icon: index == 0 ? .reminder : nil, title: "taskPage.reminders.time") {
                    DatePicker("taskPage.reminders.time", selection: binding(at: index), displayedComponents: .hourAndMinute)
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

    private func binding(at index: Int) -> Binding<Date> {
        Binding(
            get: { model.context().today.startDate(in: model.calendar, offset: times[index]) },
            set: { date in
                var updated = times
                updated[index] = LocalTime(date, in: model.calendar)
                save(updated)
            }
        )
    }

    private func save(_ updated: [LocalTime]) {
        editor.apply(task.due == nil ? [.reminderTimes(updated)] : [.reminderTimes(updated), .due(nil)])
    }
}
