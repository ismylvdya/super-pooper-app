import SwiftUI

/// The finer marks of a zoomed-in timeline (`TimelineGridDetail`): ":15", ":30", ":45" right-aligned under the hour
/// labels, paler and smaller (`TimelineMinuteLabel`), and a line every five minutes without numbers, each faded in by the zoom.
struct TimelineFineGrid: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    let hours: [Date]
    let detail: TimelineGridDetail
    let labelWidth: CGFloat
    let width: CGFloat
    let labelHeight: CGFloat
    let y: (Date) -> CGFloat

    var body: some View {
        if detail.fiveMinutes > 0 {
            ForEach(marks(every: rules.timeline.fineLineMinutes), id: \.self) { mark in
                Rectangle()
                    .fill(tokens.color(.timelineGrid))
                    .frame(width: max(width - labelWidth, 0), height: tokens.size(.gridLine))
                    .opacity(detail.fiveMinutes * tokens.opacity(.fineLine))
                    .offset(x: labelWidth, y: y(mark) - tokens.size(.gridLine) / 2)
            }
        }
        if detail.quarters > 0 {
            ForEach(marks(every: rules.timeline.quarterMinutes), id: \.self) { mark in
                TimelineMinuteLabel(minute: Int(mark.timeIntervalSince(hour(of: mark)) / 60), width: labelWidth)
                    .opacity(detail.quarters * tokens.opacity(.quarterLabel))
                    .frame(height: labelHeight)
                    .offset(y: y(mark) - labelHeight / 2)
            }
        }
    }

    /// The moments every `step` minutes past each hour, the hours themselves left out.
    private func marks(every step: Int) -> [Date] {
        hours.flatMap { hour in TimelineGridDetail.minutes(every: step).map { hour.addingTimeInterval(Double($0) * 60) } }
    }

    private func hour(of mark: Date) -> Date {
        hours.last { $0 <= mark } ?? mark
    }
}
