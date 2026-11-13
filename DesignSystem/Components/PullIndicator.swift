import SwiftUI

/// The icon a pull past an edge shows in the room it opens (a list pulled down, the first page of Tasks pulled
/// sideways): it grows and fades in with the pull, and once armed it stands a little larger. It sits in the middle of
/// the room along `axis`, never before the edge. The room starts `margin` before the indicator's own edge: the screen's
/// edge lies beyond the stack the indicator overlays, and the icon stands midway between the screen's edge and the content.
struct PullIndicator: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let icon: Icon
    /// How far the content has moved past the edge.
    let pull: CGFloat
    let threshold: CGFloat
    let isArmed: Bool
    let axis: Axis
    var margin: CGFloat = 0

    var body: some View {
        let progress = threshold > 0 ? min(pull / threshold, 1) : 0
        let start = tokens.ratio(.pullStartScale)
        let room = max((pull + margin) / 2 - margin - tokens.uiFont(.pullIcon).pointSize / 2, -margin)
        Image(systemName: icons[icon])
            .font(tokens.font(.pullIcon))
            .foregroundStyle(tokens.color(.secondaryText))
            .scaleEffect(isArmed ? tokens.ratio(.pullArmedScale) : start + (1 - start) * progress)
            .opacity(progress)
            .offset(x: axis == .horizontal ? room : 0, y: axis == .vertical ? room : 0)
            .animation(.easeOut(duration: tokens.duration(.animation)), value: isArmed)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
