import SwiftUI

/// The Today buttons: leading = morning review and problems badge, trailing = new task and search. Lying sideways
/// (`bottom` set) they stand top to bottom in their physical left-to-right order. Today puts each group in a glass bubble.
struct TodayButtons: View {
    enum Placement {
        case leading, trailing

        var items: [Item] {
            switch self {
            case .leading: [.review, .problems]
            case .trailing: [.newTask, .search]
            }
        }
    }

    enum Item { case review, problems, newTask, search }

    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let placement: Placement
    var bottom: HorizontalEdge?

    var body: some View {
        ForEach(PhysicalBottom.physicalOrder(placement.items.filter(isShown), bottom: bottom), id: \.self) { item in
            // In the system bar upright the bar sizes the buttons; in the column lying sideways each takes the size of
            // a system bar button in its bubble.
            if bottom == nil {
                button(item)
            } else {
                button(item)
                    .frame(minWidth: tokens.size(.barButton), minHeight: tokens.size(.barButton))
                    .contentShape(Capsule())
            }
        }
    }

    /// The bubble only holds what is shown (the problems badge only with problems).
    private func isShown(_ item: Item) -> Bool {
        item != .problems || (model.config.flags.problemBadge && model.problemCount > 0)
    }

    @ViewBuilder private func button(_ item: Item) -> some View {
        switch item {
        case .review:
            Button { router.isReviewPresented = true } label: { Image(systemName: icons[.review]) }
                .tint(tokens.color(.accent))
                .accessibilityLabel(Text("review.title"))
                .accessibilityIdentifier("today.review")
        case .problems:
            if model.config.flags.problemBadge, model.problemCount > 0 {
                Button { router.isProblemsPresented = true } label: {
                    HStack(spacing: tokens.space(.badgeGap)) {
                        Image(systemName: icons[.problem])
                        Text(verbatim: "\(model.problemCount)").font(tokens.font(.poolCounter))
                    }
                    .foregroundStyle(tokens.color(.problem))
                }
                .accessibilityLabel(Text("problems.title"))
            }
        case .newTask:
            Button { router.open(.newTask) } label: { Image(systemName: icons[.newTask]) }
                .tint(tokens.color(.accent))
                .accessibilityLabel(Text("task.new.title"))
                .accessibilityIdentifier("today.newTask")
        case .search:
            Button { router.open(.search(.tasksAndEvents)) } label: { Image(systemName: icons[.search]) }
                .tint(tokens.color(.accent))
                .accessibilityLabel(Text("search.title"))
                .accessibilityIdentifier("today.search")
        }
    }
}
