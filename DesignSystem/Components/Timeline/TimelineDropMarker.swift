import SwiftUI

/// The landing spot of a dragged task: its minutes (":35") in the hour column and a line across.
/// Drawn with its top at the spot; the caller offsets it there.
struct TimelineDropMarker: View {
    @Environment(\.tokens) private var tokens
    let moment: Date
    let labelWidth: CGFloat
    let width: CGFloat

    var body: some View {
        let minute = Calendar.current.component(.minute, from: moment)
        HStack(alignment: .center, spacing: tokens.space(.hourLabelGap)) {
            Text(verbatim: String(format: ":%02d", minute))
                .font(tokens.font(.timelineHour).monospacedDigit())
                .foregroundStyle(tokens.color(.accent))
                .frame(width: max(labelWidth - tokens.space(.hourLabelGap), 0), alignment: .trailing)
                .background(tokens.color(.screenBackground))
            Capsule().fill(tokens.color(.accent)).frame(height: tokens.size(.dropLine))
        }
        .frame(width: width, height: tokens.size(.dropMarkerHeight))
        .offset(y: -tokens.size(.dropMarkerHeight) / 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
