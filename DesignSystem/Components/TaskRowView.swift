import SwiftUI

/// One task or habit row: the title with its property chips on the right, on the same line (a task waiting for
/// another has the link chip, nothing else). Tasks are marked from the long-press menu, so there is no checkbox; a marked row is grey and ends
/// with its mark.
/// The same view is used in the pool, on the timeline and in widgets.
struct TaskRowView: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.titleReserve) private var reserve
    @Environment(\.bareTitleInset) private var bareInset
    @Environment(\.chipOrder) private var chipOrder
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
    /// Grey with its mark when done; the timeline shows an item there plainly (what is finished has left it).
    var showsDoneState = true
    var onOpen: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: tokens.space(.iconTextGap)) {
            title.frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, hasTrailing ? 0 : bareInset)
            if showsDetails, !chips.isEmpty {
                HStack(spacing: tokens.space(.chipGap)) { chipViews }.fixedSize()
            }
            if isDone { MarkGlyph(state: item.state, color: tokens.color(.past), size: tokens.size(.doneMark)) }
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
            .foregroundStyle(isDone ? tokens.color(.secondaryText) : tokens.color(.primaryText))
        if let onOpen {
            // Not a Button: a button also fires when a swipe (turning the page, scrolling) ends on it; the row's tap
            // gesture below gives up as soon as the finger moves.
            text
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onOpen() }
                .accessibilityIdentifier("title:\(item.task.name)")
        } else {
            text
        }
    }

    private var chips: [RowChip] {
        RowChip.chips(for: item, order: chipOrder, tokens: tokens)
    }

    private var isDone: Bool { showsDoneState && item.isDone }

    private var hasTrailing: Bool { isDone || (showsDetails && !chips.isEmpty) }
}
