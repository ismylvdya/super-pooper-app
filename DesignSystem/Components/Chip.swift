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
        HStack(spacing: tokens.space(.chipIconGap)) {
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

/// A row of chips that wraps onto the next line when it does not fit. Each line is placed by `alignment`
/// inside the width; a chip is placed by it inside its line.
struct ChipFlow: Layout {
    var spacing: CGFloat
    var alignment: Alignment = .topLeading

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX + Self.offset(of: row.width, in: bounds.width, alignment.horizontal)
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                let top = y + Self.offset(of: size.height, in: row.height, alignment.vertical)
                subviews[index].place(at: CGPoint(x: x, y: top), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private static func offset(of length: CGFloat, in space: CGFloat, _ alignment: HorizontalAlignment) -> CGFloat {
        switch alignment {
        case .center: (space - length) / 2
        case .trailing: space - length
        default: 0
        }
    }

    private static func offset(of length: CGFloat, in space: CGFloat, _ alignment: VerticalAlignment) -> CGFloat {
        switch alignment {
        case .center: (space - length) / 2
        case .bottom: space - length
        default: 0
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
