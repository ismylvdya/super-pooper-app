import SwiftUI

extension View {
    /// Pulling this scroll view down past the edge shows `icon` in the accent color, like the refresh
    /// spinner would; past the threshold it vibrates once, and letting go runs `action`.
    func pullAction(_ icon: Icon, perform action: @escaping () -> Void) -> some View {
        modifier(PullAction(icon: icon, action: action))
    }
}

private struct PullAction: ViewModifier {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let icon: Icon
    let action: () -> Void
    @State private var pull: CGFloat = 0
    @State private var isArmed = false

    func body(content: Content) -> some View {
        let threshold = tokens.size(.pullThreshold)
        content
            .onScrollGeometryChange(for: CGFloat.self) { max(0, -($0.contentOffset.y + $0.contentInsets.top)) } action: { _, new in
                pull = new
                if new >= threshold, !isArmed {
                    isArmed = true
                    Haptics.play(.medium)
                } else if new < threshold / 2 {
                    isArmed = false
                }
            }
            .onScrollPhaseChange { old, new in
                guard old == .interacting, new != .interacting else { return }
                if isArmed { action() }
                isArmed = false
            }
            .overlay(alignment: .top) {
                Image(systemName: icons[icon])
                    .font(.system(size: tokens.size(.pullIcon), weight: .semibold))
                    .foregroundStyle(tokens.color(.accent))
                    .scaleEffect(isArmed ? 1.2 : 0.6 + 0.4 * min(pull / threshold, 1))
                    .opacity(min(pull / threshold, 1))
                    .offset(y: max(pull / 2 - tokens.size(.pullIcon) / 2, 0))
                    .animation(.easeOut(duration: 0.15), value: isArmed)
                    .allowsHitTesting(false)
            }
    }
}
