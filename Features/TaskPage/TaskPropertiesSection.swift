import SwiftUI

/// What the chips and the date sheet do not set: a task's list, how it feels and its estimate. A habit's stand in
/// `HabitDaySection`.
struct TaskPropertiesSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.rules) private var rules
    let editor: TaskEditor

    private var task: TaskItem { editor.task }

    var body: some View {
        PlateSection(header: "taskPage.properties", info: "info.taskPage.properties") {
            listRow
            FeelPicker(editor: editor)
            PlateRow(icon: .estimate, title: "taskPage.estimate", info: "info.taskPage.estimate") {
                Picker("taskPage.estimate", selection: estimateBinding) {
                    ForEach(rules.estimateOptions(including: rules.day.estimate(of: task)), id: \.minutes) { Text(LocalizedStringKey($0.label)).tag($0.minutes) }
                }
                .labelsHidden()
            }
        }
    }

    /// The row shows the list's name alone, the menu each with its icon. An archived task's status has its own action in the "…"
    /// menu, and no place here.
    private var listRow: some View {
        PlateRow(icon: .status, title: "taskPage.list", info: "info.taskPage.status") {
            Menu {
                ForEach(TaskStatus.known, id: \.self) { status in
                    Toggle(isOn: Binding(get: { task.status == status },
                                         set: { _ in editor.setStatus(status, today: model.context().today) })) {
                        ListLabel(status: status)
                    }
                }
            } label: {
                AlarmSoundValue(shown: StatusText.title(task.status))
            }
            .accessibilityIdentifier("taskPage.list")
        }
    }

    private var estimateBinding: Binding<Int> {
        Binding(get: { rules.day.estimate(of: task) },
                set: { minutes in editor.apply([.timeEstimate(minutes)]) })
    }
}

/// A list in the picker, with its icon (`TaskListIcons`).
private struct ListLabel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.displayScale) private var displayScale
    let status: TaskStatus

    var body: some View {
        Label {
            Text(StatusText.title(status))
        } icon: {
            let list = TaskListIcons(icons: icons, typed: model.settings.lists.symbols)
            TabIconImage.image(list.symbol(of: status), font: .preferredFont(forTextStyle: .body), others: list.symbols(besides: status),
                               fit: tokens.bar(.tabGlyphFit), scale: displayScale)
        }
    }
}
