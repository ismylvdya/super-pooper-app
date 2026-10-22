import SwiftUI

/// Soft dissolve instead of a hard cut at scroll edges (screen background 85 % → 50 % → 0 %).
struct EdgeFade: View {
    @Environment(\.tokens) private var tokens
    enum Edge { case top, bottom }
    let edge: Edge
    var color: Color?

    var body: some View {
        let base = color ?? tokens.color(.screenBackground)
        let stops: [Gradient.Stop] = [
            .init(color: base.opacity(tokens.opacity(.fadeTop)), location: 0),
            .init(color: base.opacity(tokens.opacity(.fadeMiddle)), location: 0.75),
            .init(color: base.opacity(0), location: 1),
        ]
        LinearGradient(stops: stops, startPoint: edge == .top ? .top : .bottom, endPoint: edge == .top ? .bottom : .top)
            .frame(height: tokens.size(.fadeHeight))
            .allowsHitTesting(false)
    }
}

extension View {
    /// Fades a scroll view's content at an edge only while there is more content beyond that edge.
    func edgeFades(color: Color? = nil) -> some View {
        modifier(ScrollEdgeFades(color: color))
    }
}

private struct ScrollEdgeFades: ViewModifier {
    let color: Color?
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
            .overlay(alignment: .bottom) { if edges.bottom { EdgeFade(edge: .bottom, color: color) } }
    }
}
