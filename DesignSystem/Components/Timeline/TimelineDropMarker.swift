import SwiftUI

/// The landing spot of a dragged task: its minutes (":35") in the hour column, as the zoomed-in marks show them
/// (`TimelineMinuteLabel`), and a line across the column, the same as the hours' own lines.
/// Drawn with its top at the spot; the caller offsets it there.
struct TimelineDropMarker: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.calendar) private var calendar
    let moment: Date
    let labelWidth: CGFloat
    let width: CGFloat

    var body: some View {
        let minute = calendar.component(.minute, from: moment)
        TimelineMinuteLabel(minute: minute, width: labelWidth)
            .background(tokens.color(.screenBackground))
            .frame(width: width, height: tokens.size(.dropMarkerHeight), alignment: .leading)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(tokens.color(.timelineGrid))
                    .frame(width: max(width - labelWidth, 0), height: tokens.size(.gridLine))
                    .offset(x: labelWidth)
            }
        .offset(y: -tokens.size(.dropMarkerHeight) / 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
