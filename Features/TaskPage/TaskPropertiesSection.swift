import SwiftUI

/// Status, High, date (+ optional time), estimate, need energy, pleasant.
struct TaskPropertiesSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.rules) private var rules
    let task: TaskNote

    var body: some View {
        PlateSection(header: "taskPage.properties", info: "info.taskPage.properties") {
            if !task.isHabit { taskOnlyRows }
            PlateRow(icon: .estimate, title: "taskPage.estimate", info: "info.taskPage.estimate") {
                Picker("taskPage.estimate", selection: estimateBinding) {
                    ForEach(rules.timeEstimates, id: \.minutes) { Text(LocalizedStringKey($0.label)).tag($0.minutes) }
                }
                .labelsHidden()
            }
            PlateRow(icon: .energy, title: "taskPage.energy", info: "info.taskPage.energy") {
                Toggle("taskPage.energy", isOn: binding(\.needEnergy, change: TaskFieldChange.needEnergy)).labelsHidden()
            }
            PlateRow(icon: .pleasant, title: "taskPage.pleasant", info: "info.taskPage.pleasant") {
                Toggle("taskPage.pleasant", isOn: Binding(
                    get: { task.pleasant ?? false },
                    set: { value in Task { await model.update(task.name, [.pleasant(value)]) } }
                )).labelsHidden()
            }
        }
    }

    /// Status, High and the date make no sense for a habit: it is always active and repeats by its own rule.
    @ViewBuilder private var taskOnlyRows: some View {
        PlateRow(icon: .status, title: "taskPage.status", info: "info.taskPage.status") {
            Picker("taskPage.status", selection: Binding(
                get: { task.status },
                set: { status in
                    let changes = TaskMarking(today: model.context().today).changes(setting: status, on: task)
                    Task { await model.update(task.name, changes) }
                }
            )) {
                ForEach(TaskStatus.known, id: \.self) { Text(StatusText.title($0)).tag($0) }
                if case .other(let raw) = task.status { Text(verbatim: raw).tag(task.status) }
            }
            .labelsHidden()
        }
        PlateRow(icon: .high, title: "taskPage.high", info: "info.taskPage.high") {
            Toggle("taskPage.high", isOn: binding(\.isHighPriority, change: TaskFieldChange.highPriority))
                .labelsHidden()
                .accessibilityIdentifier("taskPage.high")
        }
        DueEditor(task: task)
    }

    private func binding<Value>(_ keyPath: KeyPath<TaskNote, Value>, change: @escaping (Value) -> TaskFieldChange) -> Binding<Value> {
        Binding(get: { task[keyPath: keyPath] },
                set: { value in Task { await model.update(task.name, [change(value)]) } })
    }

    private var estimateBinding: Binding<Int> {
        Binding(get: { rules.day.estimate(of: task) },
                set: { minutes in Task { await model.update(task.name, [.timeEstimate(minutes)]) } })
    }
}

/// The task date: a toggle; when on, a date and (child) an optional time.
struct DueEditor: View {
    @Environment(AppModel.self) private var model
    let task: TaskNote

    var body: some View {
        PlateRow(icon: .due, title: "taskPage.due", info: "info.taskPage.due") {
            Toggle("taskPage.due", isOn: Binding(
                get: { task.due != nil },
                set: { on in save(on ? TaskDue(day: model.context().today) : nil) }
            )).labelsHidden()
        }
        if let due = task.due {
            PlateRow(icon: nil, title: "taskPage.due.date", indent: true) {
                DatePicker("taskPage.due.date", selection: Binding(
                    get: { due.date(in: model.calendar) },
                    set: { save(TaskDue(day: LocalDate($0, in: model.calendar), time: due.time)) }
                ), displayedComponents: .date)
                .labelsHidden()
            }
            PlateRow(icon: nil, title: "taskPage.due.hasTime", info: "info.taskPage.time", indent: true) {
                Toggle("taskPage.due.hasTime", isOn: Binding(
                    get: { due.time != nil },
                    set: { on in save(TaskDue(day: due.day, time: on ? LocalTime(hour: 9, minute: 0) : nil)) }
                )).labelsHidden()
            }
            if let time = due.time {
                PlateRow(icon: nil, title: "taskPage.due.time", indent: true) {
                    DatePicker("taskPage.due.time", selection: Binding(
                        get: { due.day.startDate(in: model.calendar, offset: time) },
                        set: { date in
                            let parts = model.calendar.dateComponents([.hour, .minute], from: date)
                            save(TaskDue(day: due.day, time: LocalTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)))
                        }
                    ), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                }
            }
        }
    }

    private func save(_ due: TaskDue?) {
        Task { await model.update(task.name, [.due(due)]) }
    }
}

enum StatusText {
    static func title(_ status: TaskStatus) -> String {
        switch status {
        case .thisWeek: L10n.string("status.thisWeek")
        case .halfYear: L10n.string("status.halfYear")
        case .someday: L10n.string("status.someday")
        case .waiting: L10n.string("status.waiting")
        case .done: L10n.string("status.done")
        case .archived: L10n.string("status.archived")
        case .habit: L10n.string("status.habit")
        case .other(let raw): raw
        }
    }
}
