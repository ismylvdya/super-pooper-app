import SwiftUI

/// Pool rows on plates, as in the app: in the day's sections under their headers, with the high priority and started
/// looks, without chips. Above the timeline: `visibleCount` rows and a counter of the rest. Beside it (`visibleCount`
/// nil): rows down to the bottom of the widget, the last one cut, no counter.
struct WidgetPoolBlock: View {
    @Environment(\.tokens) private var tokens
    let plan: DayPlan
    let visibleCount: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.widgetGap)) {
            ForEach(shownSections) { section in
                VStack(alignment: .leading, spacing: tokens.space(.widgetGap)) {
                    if section.hasHeader {
                        // The app's section title, in the widget's small type.
                        section.titleText
                            .font(tokens.font(.widgetCaption))
                            .foregroundStyle(tokens.color(.sectionHeader))
                            .padding(.horizontal, tokens.space(.sectionHeaderInset))
                    }
                    // The same plates as Today, without chips; a worm and habits of one routine share a plate.
                    ForEach(PoolSegments.make(section.items, worms: plan.worms)) { segment in
                        PoolSegmentView(segment: segment) { item, plate in
                            PlatedPoolRow(item: item, plate: plate) {
                                TaskRowView(item: item, titleFont: tokens.font(.widgetTitle), showsDetails: false,
                                            isCompact: true, titleLineHeight: tokens.uiFont(.widgetTitle).lineHeight)
                            }
                            // A subtask sits under its parent, shifted right, as in the app's pool.
                            .padding(.leading, CGFloat(item.depth) * tokens.subtaskIndent)
                        }
                    }
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

    /// The day's sections with the rows the widget has room for; a pool without sections is one with no header.
    private var shownSections: [PoolSectionContent] {
        let shown = Set((visibleCount.map { Array(plan.pool.prefix($0)) } ?? plan.pool).map(\.id))
        let sections = plan.sections.isEmpty ? PoolSectionContent.plain(plan.pool) : plan.sections
        return sections.compactMap { section in
            let items = section.items.filter { shown.contains($0.id) }
            return items.isEmpty ? nil : PoolSectionContent(id: section.id, title: section.title, isCustom: section.isCustom, items: items)
        }
    }
}

extension PoolSectionContent {
    /// The header's words: an own section's title as the user typed it, a default one's text key.
    var titleText: Text {
        isCustom ? Text(verbatim: title) : Text(LocalizedStringKey(title))
    }
}
