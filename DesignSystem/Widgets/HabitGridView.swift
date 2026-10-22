import SwiftUI

/// A grid of days for one recurring task (weeks as columns, Monday on top). Done, Partially and
/// Twice look different; unmarked days are just empty.
struct HabitGridView: View {
    @Environment(\.tokens) private var tokens
    let title: String
    let grid: HabitGrid

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
            Text(title).font(tokens.font(.widgetTitle)).lineLimit(1)
            GeometryReader { geometry in
                let gap = tokens.space(.habitCellGap)
                let columns = CGFloat(max(grid.weeks.count, 1))
                let side = max(min((geometry.size.width - gap * (columns - 1)) / columns, (geometry.size.height - gap * 6) / 7), 2)
                HStack(spacing: gap) {
                    ForEach(grid.weeks.indices, id: \.self) { week in
                        VStack(spacing: gap) {
                            ForEach(grid.weeks[week].indices, id: \.self) { day in
                                HabitCellView(cell: grid.weeks[week][day], side: side)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .padding(tokens.space(.widgetPadding))
    }
}

struct HabitCellView: View {
    @Environment(\.tokens) private var tokens
    let cell: HabitCell
    let side: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: tokens.radius(.habitCell), style: .continuous)
        ZStack {
            switch cell {
            case .done:
                shape.fill(tokens.color(.habit))
            case .partial:
                shape.fill(tokens.color(.habit).opacity(tokens.opacity(.partialFill)))
            case .twice:
                shape.fill(tokens.color(.twice))
                Circle().fill(.white).frame(width: side * 0.35, height: side * 0.35)
            case .open:
                shape.fill(tokens.color(.habitEmpty).opacity(tokens.opacity(.habitEmpty)))
            case .notScheduled:
                shape.stroke(tokens.color(.habitEmpty).opacity(tokens.opacity(.habitEmpty)), lineWidth: 1)
            case .future:
                Color.clear
            }
        }
        .frame(width: side, height: side)
    }
}
