import SwiftUI

/// Pool rows on plates, as in the app. Above the timeline: `visibleCount` rows and a counter of the rest.
/// Beside it (`visibleCount` nil): rows down to the bottom of the widget, the last one cut, no counter.
struct WidgetPoolBlock: View {
    @Environment(\.tokens) private var tokens
    let plan: DayPlan
    let visibleCount: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.widgetGap)) {
            // The same plates as Today, without chips; habits of one routine share a plate.
            ForEach(PoolSegments.make(visibleCount.map { Array(plan.pool.prefix($0)) } ?? plan.pool)) { segment in
                PoolSegmentView(segment: segment) { item, plate in
                    TaskRowView(item: item, titleFont: tokens.font(.widgetTitle), showsDetails: false,
                                isCompact: true, titleLineHeight: tokens.uiFont(.widgetTitle).lineHeight)
                        .poolRowPlate(plate, isDone: item.isDone)
                        // A subtask sits under its parent, shifted right, as in the app's pool.
                        .padding(.leading, CGFloat(item.depth) * tokens.space(.subtaskIndent))
                }
            }
            if let visibleCount, plan.pool.count > visibleCount {
                Text(L10n.format("pool.more", plan.pool.count - visibleCount))
                    .font(tokens.font(.widgetCaption))
                    .foregroundStyle(tokens.color(.secondaryText))
            } else if plan.pool.isEmpty {
                Text("pool.empty").font(tokens.font(.widgetCaption)).foregroundStyle(tokens.color(.secondaryText))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: visibleCount == nil ? .infinity : nil, alignment: .topLeading)
        .clipped()
        // The pool starts at its first row; only the cut bottom fades (empty space under it stays empty).
        .fadingEdges(bottom: visibleCount == nil)
        .frame(idealWidth: tokens.size(.poolWidth))
    }
}
