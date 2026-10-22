import SwiftUI

/// Small rounded label: icon and/or text on a tertiary fill.
struct Chip: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    var icon: Icon?
    var text: String?
    var tint: Color?
    var isOn = true

    var body: some View {
        HStack(spacing: 3) {
            if let icon { Image(systemName: icons[icon]) }
            if let text { Text(text).lineLimit(1) }
        }
        .font(tokens.font(.chip))
        .foregroundStyle(isOn ? (tint ?? tokens.color(.secondaryText)) : tokens.color(.tertiaryText))
        .padding(.horizontal, tokens.space(.chipHorizontal))
        .padding(.vertical, tokens.space(.chipVertical))
        .background(tokens.color(.chipBackground), in: RoundedRectangle(cornerRadius: tokens.radius(.chip), style: .continuous))
    }
}

/// A row of chips that wraps onto the next line when it does not fit.
struct ChipFlow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
