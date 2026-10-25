import SwiftUI

/// The fastest way to plan a task, right under its name: High, and Today or Tomorrow (or neither).
/// All off for a new task; the same fields are in Properties with the full date editor.
struct TaskQuickChips: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let editor: TaskEditor

    var body: some View {
        let context = model.context()
        let selected = QuickDue.selection(of: editor.task.due, context: context)
        HStack(spacing: tokens.space(.chipGap)) {
            ToggleChip(icon: .high, title: "taskPage.chip.high", tint: tokens.color(.high), isOn: editor.task.isHighPriority) {
                editor.edit { [.highPriority(!$0.isHighPriority)] }
            }
            .accessibilityIdentifier("taskPage.chip.high")
            ForEach(QuickDue.allCases, id: \.self) { chip in
                ToggleChip(icon: chip == .today ? .today : .tomorrow, title: chip == .today ? "taskPage.chip.today" : "taskPage.chip.tomorrow",
                           tint: tokens.color(.task), isOn: selected == chip) {
                    editor.edit { [.due(QuickDue.toggling(chip, due: $0.due, context: context))] }
                }
                .accessibilityIdentifier(chip == .today ? "taskPage.chip.today" : "taskPage.chip.tomorrow")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// A chip that is a switch: tinted when on, grey when off.
struct ToggleChip: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let icon: Icon
    let title: LocalizedStringKey
    let tint: Color
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.play(.light)
            action()
        } label: {
            HStack(spacing: tokens.space(.chipGap)) {
                Image(systemName: icons[icon])
                Text(title).lineLimit(1)
            }
            .font(tokens.font(.toggleChip))
            .foregroundStyle(isOn ? tint : tokens.color(.secondaryText))
            .padding(.horizontal, tokens.space(.toggleChipHorizontal))
            .padding(.vertical, tokens.space(.toggleChipVertical))
            .background(isOn ? tint.opacity(tokens.opacity(.toggleChipFill)) : tokens.color(.plateBackground),
                        in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
