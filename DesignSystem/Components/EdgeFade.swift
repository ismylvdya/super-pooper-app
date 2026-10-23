import SwiftUI

/// Soft dissolve instead of a hard cut at scroll edges (screen background 85 % → 50 % → 0 %).
struct EdgeFade: View {
    @Environment(\.tokens) private var tokens
    enum Edge { case top, bottom }
    let edge: Edge
    var color: Color?
    /// Extra length past the content edge (e.g. down under the home indicator).
    var overhang: CGFloat = 0

    var body: some View {
        let base = color ?? tokens.color(.screenBackground)
        let stops: [Gradient.Stop] = [
            .init(color: base.opacity(tokens.opacity(.fadeTop)), location: 0),
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
    /// `bottomExtension`: the scroll view reaches under the home indicator; the bottom fade
    /// then runs all the way down to the screen edge.
    func edgeFades(color: Color? = nil, bottomExtension: CGFloat = 0) -> some View {
        modifier(ScrollEdgeFades(color: color, bottomExtension: bottomExtension))
    }
}

private struct ScrollEdgeFades: ViewModifier {
    let color: Color?
    let bottomExtension: CGFloat
    @State private var edges = ScrollEdges()

    struct ScrollEdges: Equatable {
        var top = false
        var bottom = false
    }

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: ScrollEdges.self) { geometry in
                ScrollEdges(top: geometry.contentOffset.y > geometry.contentInsets.top * -1 + 1,
                            bottom: geometry.contentOffset.y + geometry.containerSize.height < geometry.contentSize.height - 1)
            } action: { _, new in edges = new }
            .overlay(alignment: .top) { if edges.top { EdgeFade(edge: .top, color: color) } }
            .overlay(alignment: .bottom) {
                if edges.bottom { EdgeFade(edge: .bottom, color: color, overhang: bottomExtension) }
            }
    }
}
