import SwiftUI

extension View {
    /// Pulling this scroll view down past its top shows `icon`; past the threshold it vibrates once, and
    /// letting go runs `action` (used to load more of a list instead of refreshing it).
    func pullToExtend(icon: Icon, perform action: @escaping () -> Void) -> some View {
        modifier(PullToExtend(icon: icon, action: action))
    }
}

private struct PullToExtend: ViewModifier {
    @Environment(\.rules) private var rules
    let icon: Icon
    let action: () -> Void
    @State private var pull: CGFloat = 0
    @State private var arming = PullArming()

    func body(content: Content) -> some View {
        let threshold = rules.gestures.pullThreshold
        content
            .onScrollGeometryChange(for: CGFloat.self) { max(0, -($0.contentOffset.y + $0.contentInsets.top)) } action: { _, new in
                pull = new
                if arming.update(pull: new, threshold: threshold) { Haptics.play(.pullArmed) }
            }
            .onScrollPhaseChange { old, new in
                guard old == .interacting, new != .interacting else { return }
                if arming.release() { action() }
            }
            .overlay(alignment: .top) {
                PullIndicator(icon: icon, pull: pull, threshold: threshold, isArmed: arming.isArmed, axis: .vertical)
            }
    }
}
