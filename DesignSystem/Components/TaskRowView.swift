import SwiftUI

/// One task or habit row: the title with its property icons on the right, bare, without capsules, on the same line (a task waiting for
/// another has the link chip, nothing else). Tasks are marked from the long-press menu, so there is no checkbox; a marked row is grey and ends
/// with its mark.
/// The same view is used in the pool, on the timeline and in widgets.
struct TaskRowView: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.titleReserve) private var reserve
    @Environment(\.plateTrailingInset) private var plateInset
    @Environment(\.chipOrder) private var chipOrder
    @Environment(\.highPriorityLook) private var highPriorityLook
    let item: DayItem
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
        // The title fades out `fadeGap` before the chips, the corner marks or the plate's edge (`TitleFade`).
        HStack(alignment: .top, spacing: tokens.space(.fadeGap)) {
            HStack(alignment: .top, spacing: tokens.space(.priorityIconGap)) {
                if HighPriorityMark(look: highPriorityLook, task: item.task).leadsWithIcon { priorityIcon }
                title.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.trailing, hasTrailing ? 0 : TitleFade.trailing(corner: reserve, plateInset: plateInset, gap: tokens.space(.fadeGap)))
            if showsDetails, !chips.isEmpty {
                HStack(spacing: tokens.space(.chipGap)) { chipViews }.fixedSize()
            }
            if isDone { MarkGlyph(state: item.state, color: tokens.color(.past), size: tokens.size(.doneMark)) }
        }
        .contentShape(Rectangle())
        // Anywhere on the row opens the task (chips included).
        .onTapGesture { onOpen?() }
    }

    /// The priority icon in the title's font, centred on its first line.
    private var priorityIcon: some View {
        IconGlyph(.high, font: .taskTitle)
            .font(titleFont ?? tokens.font(.taskTitle))
            .foregroundStyle(tokens.color(of: .high))
            .frame(height: titleLineHeight ?? tokens.uiFont(.taskTitle).lineHeight)
            .accessibilityIdentifier("highPriority:\(item.task.name)")
    }

    private var chipViews: some View {
        ForEach(chips) { chip in
            IconGlyph(chip.look.icon, font: .chip)
                .font(tokens.font(.chip))
                .foregroundStyle(tokens.color(of: chip.look))
        }
    }

    /// Limited titles fade out instead of ending with "…".
    @ViewBuilder private var titleText: some View {
        let font = titleFont ?? tokens.font(.taskTitle)
        if let lines = titleLineLimit ?? (isCompact ? 1 : nil) {
            FadingText(text: item.task.name, font: font, lineHeight: titleLineHeight ?? tokens.uiFont(.taskTitle).lineHeight,
                       lines: lines)
        } else {
            Text(item.task.name).font(font).multilineTextAlignment(.leading)
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
        RowChip.chips(for: item, order: chipOrder)
    }

    private var isDone: Bool { showsDoneState && item.isDone }

    private var hasTrailing: Bool { isDone || (showsDetails && !chips.isEmpty) }
}
