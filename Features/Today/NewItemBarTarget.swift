import SwiftUI

/// What Today's bar offers in place of its buttons while the "+" is dragged: a new section of the day's pool with the new
/// task in it (instead of Lists), and a subtask of the task the "+" was last under in the pool (instead of Search).
enum NewItemBarTarget: Hashable {
    case newSection
    case subtask(of: String)

    enum Kind { case newSection, subtask }
}

/// A bar button the dragged "+" lands on: it lights up under the finger, with a step to feel, and letting go there does
/// `onLand`. Dimmed while it has nothing to do (`isOffered`), and then it takes nothing.
struct NewItemBarButton: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.actions) private var actions
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    let target: NewItemBarTarget?
    /// Dimmed with no target, for the bar to keep its shape.
    var symbolKind: NewItemBarTarget.Kind
    var isOffered: Bool { target != nil }
    let onLand: (NewItemBarTarget) -> Void
    @State private var frame: CGRect = .zero
    @State private var isUnder = false

    var body: some View {
        Image(systemName: symbol)
            .font(tokens.font(.chip))
            .foregroundStyle(isUnder ? tokens.color(.accent) : tokens.color(.primaryText))
            .scaleEffect(isUnder ? tokens.ratio(.pullArmedScale) : 1)
            .opacity(isOffered ? 1 : tokens.opacity(.blocked))
            .frame(minWidth: tokens.bar(.barButton), minHeight: tokens.bar(.barButton))
            .contentShape(Rectangle())
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .onChange(of: drag?.newItemPoint) { _, point in moved(to: point) }
            .animation(tokens.animation, value: isUnder)
            .accessibilityLabel(Text(title))
            .accessibilityIdentifier("today.newItem.\(String(describing: symbolKind))")
    }

    private var symbol: String {
        switch symbolKind {
        case .newSection: actions.definition(.newSection).icon
        case .subtask: icons[.newSubtask]
        }
    }

    private var title: LocalizedStringKey {
        switch symbolKind {
        case .newSection: "action.newSection"
        case .subtask: "today.newItem.subtask"
        }
    }

    private var owner: String { "bar." + String(describing: symbolKind) }

    private func moved(to point: CGPoint?) {
        let under = isOffered && point.map(frame.contains) == true
        guard under != isUnder else { return }
        isUnder = under
        if under, let target {
            Haptics.play(.dragStep)
            drag?.setNewItemLanding(owner) { onLand(target) }
        } else {
            drag?.clearNewItemLanding(owner)
        }
    }
}
