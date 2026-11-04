import SwiftUI

/// The fastest way to plan a task, right under its name, in two rows: Today, Tomorrow and the date chip, which opens the
/// date sheet and names another day or a time; then icons alone: High priority, a chip's width apart from Pleasant and
/// Need energy. All off for a new task.
/// What the chips set is not repeated in Properties.
struct TaskChipRows: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let editor: TaskEditor
    @State private var isPickingDate = false

    var body: some View {
        let spacing = tokens.space(.chipGap)
        VStack(spacing: spacing) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: spacing) {
                    dueChips(fades: false)
                    dateChip
                }
                // A long date stays in the row: the chips beside it give way and their titles dissolve.
                HStack(spacing: spacing) {
                    dueChips(fades: true)
                    dateChip.fixedSize().layoutPriority(1)
                }
            }
            HStack(spacing: spacing) {
                highChip
                highChip.hidden().accessibilityHidden(true)
                feelChips
            }
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $isPickingDate) {
            DuePickerSheet(pick: DuePick(task: editor.task, today: model.context().today), choosesZone: true) { pick in
                editor.edit { task in pick?.edits(from: task) ?? [.due(nil)] }
            }
        }
    }

    private var highChip: some View {
        ToggleChip(.high, isOn: editor.task.isHighPriority) {
            Haptics.play(.select)
            editor.edit { [.highPriority(!$0.isHighPriority)] }
        }
        .accessibilityLabel(Text("taskPage.chip.high"))
        .accessibilityIdentifier("taskPage.chip.high")
    }

    @ViewBuilder private func dueChips(fades: Bool) -> some View {
        let context = model.context()
        let selected = QuickDue.selection(of: editor.task, context: context)
        ForEach(QuickDue.allCases, id: \.self) { chip in
            ToggleChip(icon: chip.icon, title: chip.title, tint: .task, isOn: selected == chip, fadesTitle: fades) {
                Haptics.play(.select)
                editor.edit { [.due(QuickDue.toggling(chip, task: $0, context: context))] }
            }
            .accessibilityIdentifier(chip.chipIdentifier)
        }
    }

    /// The day and the time it names are each a text of their own.
    private var dateChip: some View {
        let shown = DateChip.shown(of: editor.task, context: model.context())
        let values = [shown.day.map { DateText.format($0, .dateTime.month(.abbreviated).day(), calendar: model.calendar) },
                      shown.time?.string].compactMap { $0 }
        return ToggleChip(icon: .datePick, values: values, tint: .task, isOn: !values.isEmpty) {
            Haptics.play(.select)
            isPickingDate = true
        }
        .accessibilityIdentifier("taskPage.chip.date")
    }

    @ViewBuilder private var feelChips: some View {
        ForEach(FeelChip.allCases, id: \.self) { chip in
            ToggleChip(chip.look, isOn: editor.task.feel == chip.feel) {
                Haptics.play(.select)
                editor.edit { [.feel(FeelChip.toggling(chip, current: $0.feel))] }
            }
            .accessibilityLabel(Text(chip.title))
            .accessibilityIdentifier(chip.chipIdentifier)
        }
    }
}
