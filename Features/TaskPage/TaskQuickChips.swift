import SwiftUI

/// The fastest way to plan a task, right under its name: High, and Today or Tomorrow (or neither).
/// All off for a new task; the same fields are in Properties with the full date editor.
struct TaskQuickChips: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let editor: TaskEditor

    /// One line when the three fit; otherwise High on the first line and the two dates on the second.
    var body: some View {
        let spacing = tokens.space(.chipGap)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing) {
                highChip
                dueChips
            }
            VStack(spacing: spacing) {
                highChip
                HStack(spacing: spacing) { dueChips }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var highChip: some View {
        ToggleChip(.high, title: "taskPage.chip.high", isOn: editor.task.isHighPriority) {
            Haptics.play(.select)
            editor.edit { [.highPriority(!$0.isHighPriority)] }
        }
        .accessibilityIdentifier("taskPage.chip.high")
    }

    @ViewBuilder private var dueChips: some View {
        let context = model.context()
        let selected = QuickDue.selection(of: editor.task, context: context)
        ForEach(QuickDue.allCases, id: \.self) { chip in
            ToggleChip(icon: chip.icon, title: chip.title, tint: .task, isOn: selected == chip) {
                Haptics.play(.select)
                editor.edit { [.due(QuickDue.toggling(chip, task: $0, context: context))] }
            }
            .accessibilityIdentifier(chip.chipIdentifier)
        }
    }
}
