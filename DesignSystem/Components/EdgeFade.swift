import SwiftUI

/// Soft dissolve instead of a hard cut at scroll edges (screen background 85 % → 50 % → 0 %; a solid one hides the
/// content completely at the edge).
struct EdgeFade: View {
    @Environment(\.tokens) private var tokens
    enum Edge { case top, bottom }
    let edge: Edge
    var color: Color?
    var isSolid = false
    /// Extra length past the content edge (e.g. down under the home indicator).
    var overhang: CGFloat = 0

    var body: some View {
        let base = color ?? tokens.color(.screenBackground)
        let stops: [Gradient.Stop] = [
            .init(color: isSolid ? base : base.opacity(tokens.opacity(.fadeTop)), location: 0),
            .init(color: base.opacity(tokens.opacity(.fadeMiddle)), location: 0.75),
            .init(color: base.opacity(0), location: 1),
        ]
        LinearGradient(stops: stops, startPoint: edge == .top ? .top : .bottom, endPoint: edge == .top ? .bottom : .top)
            .frame(height: tokens.size(.fadeHeight) + overhang)
            .allowsHitTesting(false)
    }
}

extension View {
    /// Fades a scroll view's content at an edge only while there is more content beyond that edge.
    /// `topInset`: something solid covers the top of the scroll view (the all-day strip); the top fade starts
    /// under it. `bottomExtension`: the scroll view reaches under the home indicator; the bottom fade
    /// then runs all the way down to the screen edge. `solidTop`: nothing of the content shows at the top edge.
    func edgeFades(color: Color? = nil, topInset: CGFloat = 0, bottomExtension: CGFloat = 0, solidTop: Bool = false) -> some View {
        modifier(ScrollEdgeFades(color: color, topInset: topInset, bottomExtension: bottomExtension, solidTop: solidTop))
    }
}

/// Both edges fade the same way: the same gradient, faded in by how far the content reaches past
/// the edge (over one fade length), so neither edge pops in.
private struct ScrollEdgeFades: ViewModifier {
    @Environment(\.tokens) private var tokens
    let color: Color?
    let topInset: CGFloat
    let bottomExtension: CGFloat
    let solidTop: Bool
    @State private var edges = ScrollEdges()

    struct ScrollEdges: Equatable {
        /// Content hidden above and below the visible area, in points.
        var above: CGFloat = 0
        var below: CGFloat = 0
    }

    func body(content: Content) -> some View {
        let length = tokens.size(.fadeHeight)
        content
            .onScrollGeometryChange(for: ScrollEdges.self) { geometry in
                ScrollEdges(above: max(geometry.contentOffset.y + geometry.contentInsets.top, 0),
                            below: max(geometry.contentSize.height + geometry.contentInsets.bottom
                                       - geometry.contentOffset.y - geometry.containerSize.height, 0))
            } action: { _, new in edges = new }
            .overlay(alignment: .top) {
                EdgeFade(edge: .top, color: color, isSolid: solidTop).opacity(min(edges.above / length, 1)).padding(.top, topInset)
            }
            .overlay(alignment: .bottom) {
                EdgeFade(edge: .bottom, color: color, overhang: bottomExtension).opacity(min(edges.below / length, 1))
            }
    }
}

extension View {
    /// Dissolves the content itself at its edges, to transparent whatever is behind it: for widgets, whose background
    /// the system may swap (dark, tinted and clear Home Screens), so a gradient of a background color would show.
    func fadingEdges(top: Bool = false, bottom: Bool = false) -> some View {
        modifier(FadingEdgesMask(top: top, bottom: bottom))
    }
}

/// The same dissolve as `EdgeFade`, as the content's transparency.
private struct FadingEdgesMask: ViewModifier {
    @Environment(\.tokens) private var tokens
    let top: Bool
    let bottom: Bool

    func body(content: Content) -> some View {
        content.mask {
            VStack(spacing: 0) {
                if top { gradient(.top) }
                Rectangle()
                if bottom { gradient(.bottom) }
            }
        }
    }

    private func gradient(_ edge: EdgeFade.Edge) -> some View {
        let stops: [Gradient.Stop] = [
            .init(color: .black.opacity(1 - tokens.opacity(.fadeTop)), location: 0),
            .init(color: .black.opacity(1 - tokens.opacity(.fadeMiddle)), location: 0.75),
            .init(color: .black, location: 1),
        ]
        return LinearGradient(stops: stops, startPoint: edge == .top ? .top : .bottom, endPoint: edge == .top ? .bottom : .top)
            .frame(height: tokens.size(.fadeHeight))
    }
}
