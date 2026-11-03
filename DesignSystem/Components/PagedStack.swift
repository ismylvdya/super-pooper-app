import SwiftUI
import UniformTypeIdentifiers

/// Pages of almost the full width, side by side (`PageStrip`): the shown page leaves its neighbours' `peeks` visible at
/// the edges (each page has its own: how much of it stays in sight while another page is shown; zero hides it), and
/// tapping a visible edge (or dragging something onto an edge) turns to that neighbour. `drag` moves the pages with a
/// finger that is turning them (clamped at the first and the last page); `pull` moves them past the first page (a pull
/// that opens another page before it). `edgeInset` is how far the screen's edge is beyond the stack: a page behind
/// the edge shows there too, and an edge of a hidden neighbour lies there. Places count from `home`, so pages added
/// before it move nothing in sight.
struct PagedStack<Page: Hashable, Content: View>: View {
    let pages: [Page]
    let spacing: CGFloat
    let peeks: [CGFloat]
    var edgeInset: CGFloat = 0
    var home = 0
    var page = 0
    var drag: CGFloat = 0
    var pull: CGFloat = 0
    /// What an edge says it turns to (VoiceOver, UI tests).
    var edgeLabel: (Page) -> Text = { _ in Text(verbatim: "") }
    var onTurn: ((Int) -> Void)?
    @ViewBuilder let content: (Page) -> Content

    var body: some View {
        GeometryReader { geometry in
            let strip = PageStrip(count: pages.count, width: geometry.size.width, spacing: spacing, peeks: peeks,
                                  edgeInset: edgeInset, home: home)
            let shown = strip.offset(showing: page) + drag
            let offset = min(max(shown, strip.offset(showing: pages.count - 1)), strip.offset(showing: 0)) + pull
            ZStack(alignment: .topLeading) {
                ForEach(Array(pages.enumerated()), id: \.element) { index, item in
                    content(item)
                        .frame(width: strip.width(of: index), height: geometry.size.height)
                        .offset(x: strip.origin(of: index) + offset)
                        .zIndex(LiftLayer.block(at: index, of: pages.count))
                }
            }
            // The edges belong to the screen, not to the moving strip of pages.
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .overlay(alignment: .leading) { edge(to: page - 1, leading: true, strip: strip) }
            .overlay(alignment: .trailing) { edge(to: page + 1, leading: false, strip: strip) }
        }
    }

    /// The edge of a neighbour turns to it instead of acting on what it shows: a tap on its visible peek, or a drag
    /// reaching it. A neighbour without a peek has its edge in the screen's margin beside the stack.
    @ViewBuilder private func edge(to other: Int, leading: Bool, strip: PageStrip) -> some View {
        if let onTurn, pages.indices.contains(other) {
            let peek = strip.peek(of: other)
            let margin = leading || peek == 0 ? edgeInset : 0
            Color.clear
                .frame(width: peek + margin)
                .contentShape(Rectangle())
                .onTapGesture { if peek > 0 { onTurn(other) } }
                .onDrop(of: [.text], delegate: PageEdgeDrop { onTurn(other) })
                .accessibilityElement()
                .accessibilityLabel(edgeLabel(pages[other]))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onTurn(other) }
                .accessibilityIdentifier("today.pageEdge")
                .offset(x: leading ? -margin : margin)
        }
    }
}

/// A drag that reaches the edge of another page turns to it; nothing is dropped there.
private struct PageEdgeDrop: DropDelegate {
    let turn: () -> Void

    func dropEntered(info: DropInfo) {
        turn()
    }

    /// Without a proposal the system marks the drag with a green "+".
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        false
    }
}
