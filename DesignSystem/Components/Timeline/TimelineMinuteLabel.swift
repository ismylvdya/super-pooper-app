import SwiftUI

/// Minutes past the hour (":15") in the hour column: the marks of a zoomed-in timeline and the landing spot of a drag
/// look the same. Right-aligned next to the grid, centred on its line by the caller.
struct TimelineMinuteLabel: View {
    @Environment(\.tokens) private var tokens
    let minute: Int
    let width: CGFloat

    var body: some View {
        Text(L10n.format("timeline.dropMinutes", minute))
            .font(tokens.font(.timelineMinutes).monospacedDigit())
            .foregroundStyle(tokens.color(.tertiaryText))
            .frame(width: max(width - tokens.space(.hourLabelGap), 0), alignment: .trailing)
    }
}
