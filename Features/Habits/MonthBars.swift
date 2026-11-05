import SwiftUI

/// Marked days by month, the oldest month on top: full names flush right, then a bar in scale with the longest and its
/// number at the bar's end.
struct MonthBars: View {
    @Environment(\.tokens) private var tokens
    let title: LocalizedStringKey
    let color: Color
    let months: [(name: String, count: Int)]

    var body: some View {
        let top = max(months.map(\.count).max() ?? 0, 1)
        VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
            Text(title).secondaryText()
            Grid(horizontalSpacing: tokens.space(.chipGap), verticalSpacing: tokens.space(.habitCellGap)) {
                ForEach(Array(months.enumerated()), id: \.offset) { _, month in
                    GridRow {
                        Text(verbatim: month.name)
                            .secondaryText()
                            .lineLimit(1)
                            .fixedSize()
                            .gridColumnAlignment(.trailing)
                        bar(month.count, top: top)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func bar(_ count: Int, top: Int) -> some View {
        ScaledBar(share: Double(count) / Double(top), gap: tokens.space(.chipGap), minWidth: tokens.size(.habitMonthBarMin)) {
            RoundedRectangle(cornerRadius: tokens.radius(.habitCell), style: .continuous)
                .fill(color.opacity(count == 0 ? tokens.opacity(.habitEmpty) : 1))
                .frame(height: tokens.size(.habitMonthBar))
            number(count)
            number(top).hidden()
        }
    }

    private func number(_ value: Int) -> some View {
        Text(verbatim: "\(value)").font(tokens.font(.caption)).foregroundStyle(tokens.color(.tertiaryText)).fixedSize()
    }
}

/// A bar, its number after it and the longest number, which only keeps the room: the bar of `share` 1 and that number
/// take the whole width offered.
private struct ScaledBar: Layout {
    let share: Double
    let gap: CGFloat
    let minWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.replacingUnspecifiedDimensions().width,
               height: subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let room = bounds.width - subviews[2].sizeThatFits(.unspecified).width - gap
        let width = max(room * share, minWidth)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(width: width, height: nil))
        subviews[1].place(at: CGPoint(x: bounds.minX + width + gap, y: bounds.midY), anchor: .leading, proposal: .unspecified)
        subviews[2].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: .unspecified)
    }
}
