import SwiftUI

/// One task or habit row: title and property chips (a task waiting for another has the link chip, nothing
/// else). Tasks are marked from the long-press menu, so there is no checkbox; a marked row is grey and ends
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
    /// Narrow columns: one title line and one chip line that dissolves on the right.
    var isCompact = false
    /// Title lines; nil = compact rows get one line, others wrap freely.
    var titleLineLimit: Int?
    /// Line height of `titleFont` (nil = the task title token), for fading the last line.
    var titleLineHeight: CGFloat?
    var onOpen: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: tokens.space(.iconTextGap)) {
            VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
                title
                if showsDetails, !chips.isEmpty {
                    if isCompact {
                        // An overlay never widens the row: chips that don't fit dissolve on the right.
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: tokens.uiFont(.chip).lineHeight + tokens.space(.chipVertical) * 2)
                            .overlay(alignment: .leading) {
                                HStack(spacing: tokens.space(.chipGap)) { chipViews }.fixedSize()
                            }
                            .clipped()
                            .mask(TrailingFadeMask(width: tokens.size(.fadeHeight)))
                    } else {
                        ChipFlow(spacing: tokens.space(.chipGap)) { chipViews }
                    }
                }
            }
            Spacer(minLength: 0)
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
