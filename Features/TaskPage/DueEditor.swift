import SwiftUI

/// The task date: a toggle; when on, a date and (child) an optional time.
struct DueEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.rules) private var rules
    let editor: TaskEditor

    private var task: TaskItem { editor.task }

    var body: some View {
        PlateRow(icon: .due, title: "taskPage.due", info: "info.taskPage.due") {
            Toggle("taskPage.due", isOn: Binding(
                get: { task.due != nil },
                set: { on in save(on ? TaskDue(day: model.context().today) : nil) }
            )).labelsHidden()
        }
        if let due = task.due {
            PlateRow(icon: nil, title: "taskPage.due.date", indent: true) {
                DayField("taskPage.due.date", day: Binding(get: { due.day }, set: { save(TaskDue(day: $0, time: due.time)) }))
                    .labelsHidden()
            }
            PlateRow(icon: nil, title: "taskPage.due.hasTime", info: "info.taskPage.time", indent: true) {
                Toggle("taskPage.due.hasTime", isOn: Binding(
                    get: { due.time != nil },
                    set: { on in save(TaskDue(day: due.day, time: on ? rules.editing.defaultTime : nil)) }
                )).labelsHidden()
            }
            if let time = due.time {
                PlateRow(icon: nil, title: "taskPage.due.time", indent: true) {
                    TimeField("taskPage.due.time", time: Binding(get: { time }, set: { save(TaskDue(day: due.day, time: $0)) }),
                              on: due.day)
                    .labelsHidden()
                }
            }
        }
    }

    private func save(_ due: TaskDue?) {
        editor.apply([.due(due)])
    }
}
