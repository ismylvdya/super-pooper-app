import SwiftUI

/// The Today buttons: leading = Lists (the icon picked in the settings) with the problems badge, trailing = search.
/// Lying sideways (`bottom` set) they stand top to bottom in their physical left-to-right order. Today puts each group in
/// a glass bubble.
struct TodayButtons: View {
    enum Placement {
        case leading, trailing

        var items: [Item] {
            switch self {
            case .leading: [.lists]
            case .trailing: [.search]
            }
        }
    }

    enum Item { case lists, search }

    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.displayScale) private var displayScale
    let placement: Placement
    var bottom: HorizontalEdge?
    /// Upright: where each button stands on screen (nil when it is gone), for the room left between the groups.
    var onFrame: ((Item, CGRect?) -> Void)?

    /// The number on the Lists button: the problems, only when there are some and the badge is on.
    static func badgeCount(problemCount: Int, flagOn: Bool) -> Int? {
        flagOn && problemCount > 0 ? problemCount : nil
    }

    var body: some View {
        ForEach(PhysicalBottom.physicalOrder(placement.items, bottom: bottom), id: \.self) { item in
            // In the system bar upright the bar sizes the buttons; in the column lying sideways each takes the size of
            // a system bar button in its bubble.
            if bottom == nil {
                button(item)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onFrame?(item, $0) }
                    .onDisappear { onFrame?(item, nil) }
            } else {
                button(item)
                    .frame(minWidth: tokens.bar(.barButton), minHeight: tokens.bar(.barButton))
                    .contentShape(Capsule())
            }
        }
    }

    @ViewBuilder private func button(_ item: Item) -> some View {
        switch item {
        case .lists:
            let badge = Self.badgeCount(problemCount: model.problemCount, flagOn: model.config.flags.problemBadge)
            Button { router.open(.lists) } label: {
                // A hand-drawn gun stands within the bar's own symbols, as it did among the tabs.
                TabIconImage.image(icons[model.listsIcon], font: tokens.uiFont(.barIcon), others: [icons[.search]],
                                   fit: tokens.bar(.tabGlyphFit), scale: displayScale)
                    .offset(x: -tokens.bar(.tabGlyphShiftLeft), y: tokens.bar(.tabGlyphShiftDown))
                    .overlay(alignment: .topTrailing) { if let badge { ProblemBadge(count: badge) } }
            }
            .tint(tokens.color(.accentToolbar))
            .accessibilityLabel(Text("lists.title"))
            .accessibilityValue(badge.map { Text("problems.badge \($0)") } ?? Text(verbatim: ""))
            .accessibilityIdentifier("today.lists")
        case .search:
            Button { router.open(.search(.tasksAndEvents)) } label: { SearchGlyph() }
                .tint(tokens.color(.accentToolbar))
                .accessibilityLabel(Text("search.title"))
                .accessibilityIdentifier("today.search")
        }
    }
}

/// The number of problems in a capsule of the problem color, over a button's top trailing corner.
private struct ProblemBadge: View {
    @Environment(\.tokens) private var tokens
    let count: Int

    var body: some View {
        Text(verbatim: "\(count)")
            .font(tokens.font(.linkBadge))
            .monospacedDigit()
            .foregroundStyle(tokens.color(.screenBackground))
            .padding(.horizontal, tokens.space(.badgeGap))
            .frame(minWidth: tokens.size(.problemBadge), minHeight: tokens.size(.problemBadge))
            .background(tokens.color(.problem), in: Capsule())
            .fixedSize()
            .alignmentGuide(.top) { $0.height / 2 }
            .alignmentGuide(.trailing) { $0.width / 2 }
            .accessibilityIdentifier("today.problemBadge")
    }
}
