import SwiftUI

/// One task or habit row: the title with its property chips on the right, on the same line (a task waiting for
/// another has the link chip, nothing else). Tasks are marked from the long-press menu, so there is no checkbox; a marked row is grey and ends
/// with its mark.
/// The same view is used in the pool, on the timeline and in widgets.
struct TaskRowView: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.titleReserve) private var reserve
    @Environment(\.rules) private var rules
    let item: DayItem
    let today: LocalDate
    var titleFont: Font?
    /// Chips; widgets hide them to stay compact.
    var showsDetails = true
    /// Narrow columns: one title line that dissolves before the chips.
    var isCompact = false
    /// Title lines; nil = compact rows get one line, others wrap freely.
    var titleLineLimit: Int?
    /// Line height of `titleFont` (nil = the task title token), for fading the last line.
    var titleLineHeight: CGFloat?
    var onOpen: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: tokens.space(.iconTextGap)) {
            title.frame(maxWidth: .infinity, alignment: .leading)
            if showsDetails, !chips.isEmpty {
                HStack(spacing: tokens.space(.chipGap)) { chipViews }.fixedSize()
            }
            if item.isDone { MarkGlyph(state: item.state, color: tokens.color(.past), size: tokens.size(.doneMark)) }
        }
        .contentShape(Rectangle())
        // Anywhere on the row opens the task (chips included).
        .onTapGesture { onOpen?() }
    }

    private var chipViews: some View {
        ForEach(chips) { chip in Chip(icon: chip.icon, text: chip.text, tint: chip.tint) }
    }

    /// Limited titles fade out instead of ending with "…".
    @ViewBuilder private var titleText: some View {
        let font = titleFont ?? tokens.font(.taskTitle)
        if let lines = titleLineLimit ?? (isCompact ? 1 : nil) {
            FadingText(text: item.task.name, font: font, lineHeight: titleLineHeight ?? tokens.uiFont(.taskTitle).lineHeight,
                       lines: lines, reserve: reserve)
        } else {
            Text(item.task.name).font(font).multilineTextAlignment(.leading).padding(.trailing, reserve)
        }
    }

    @ViewBuilder private var title: some View {
        let text = titleText
            .foregroundStyle(item.isDone ? tokens.color(.secondaryText) : tokens.color(.primaryText))
        if let onOpen {
            Button(action: onOpen) { text }
                .buttonStyle(.plain)
                .accessibilityIdentifier("title:\(item.task.name)")
        } else {
            text
        }
    }

    private var chips: [RowChip] {
        RowChip.chips(for: item, today: today, rules: rules, tokens: tokens)
    }
}
