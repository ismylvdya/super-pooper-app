import SwiftUI

enum PagedStackEdge: Hashable {
    case page(Int)
    case unopenedLeadingPage
}

struct CarryEdgeInsets {
    let screen: CGRect
    let width: CGFloat
}

/// Pages of almost the full width, side by side (`PageStrip`): the shown page leaves its neighbours' peeks (`peekShares` of
/// the width) visible at
/// the edges (each page has its own: how much of it stays in sight while another page is shown; zero hides it), and
/// tapping a visible edge (or dragging something onto an edge) turns to that neighbour. `drag` moves the pages with a
/// finger that is turning them (clamped at the first and the last page); `pull` moves them past the first page (a pull
/// that opens another page before it). `edgeInset` is how far the screen's edge is beyond the stack: a page behind
/// the edge shows there too, and an edge of a hidden neighbour lies there. Places count from `home`, so pages added
/// before it move nothing in sight.
struct PagedStack<Page: Hashable, Content: View>: View {
    let pages: [Page]
    let spacing: CGFloat
    /// Each page's peek as a share of the stack's width.
    let peekShares: [Double]
    var edgeInset: CGFloat = 0
    var home = 0
    /// The first pages stay in sight of each other by `listPeek` (`PageStrip`).
    var listCount = 0
    var listPeek: CGFloat = 0
    var hiddenLists = 0
    /// Pages of half the width, two in sight (`PageStrip.halves`).
    var halves = false
    var page = 0
    var drag: CGFloat = 0
    var pull: CGFloat = 0
    /// What an edge says it turns to (VoiceOver, UI tests).
    var edgeLabel: (Page) -> Text = { _ in Text(verbatim: "") }
    var onTurn: ((Int) -> Void)?
    /// The leading edge can also reveal a page that has yet to be opened.
    var opensLeadingPage = false
    /// The drag zones use the screen's edges and a common width, independent of the pages' peeks.
    var carryEdgeInsets: CarryEdgeInsets?
    var onEdgeFrames: (([PagedStackEdge: CGRect]) -> Void)?
    @ViewBuilder let content: (Page) -> Content
    /// How far past the stack pages may show when they are not halves (into the screen's margins).
    private static var unclipped: CGFloat { 10_000 }

    var body: some View {
        GeometryReader { geometry in
            let strip = PageStrip(count: pages.count, width: geometry.size.width, spacing: spacing,
                                  peeks: peekShares.map { CGFloat($0) * geometry.size.width },
                                  edgeInset: edgeInset, home: home, listCount: listCount, listPeek: listPeek, hiddenLists: hiddenLists,
                                  halves: halves)
            let shown = strip.offset(showing: page) + drag
            let offset = min(max(shown, strip.offset(showing: pages.count - 1)), strip.offset(showing: 0)) + pull
            ZStack(alignment: .topLeading) {
                ForEach(Array(pages.enumerated()), id: \.element) { index, item in
                    content(item)
                        .frame(width: strip.width(of: index), height: geometry.size.height)
                        // A list not opened yet is not drawn, though a pull moves the pages: only the pull's icon shows,
                        // and the list comes in as it opens.
                        .opacity(index < hiddenLists ? 0 : 1)
                        .offset(x: strip.origin(of: index) + offset)
                        .zIndex(LiftLayer.block(at: index, of: pages.count))
                }
            }
            // The edges belong to the screen, not to the moving strip of pages.
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            // Halves: the two pages in sight fill the stack; the next ones stay out of the screen's margins.
            .clipShape(Rectangle().inset(by: halves ? 0 : -Self.unclipped))
            .overlay(alignment: .leading) {
                if !opensLeadingPage {
                    edge(to: page - 1, leading: true, strip: strip)
                }
            }
            .overlay(alignment: .trailing) {
                edge(to: page + 1, leading: false, strip: strip)
            }
            .onChange(of: carryEdgeFrames, initial: true) { _, frames in
                onEdgeFrames?(frames)
            }
            .onDisappear { onEdgeFrames?([:]) }
        }
    }

    private var carryEdgeFrames: [PagedStackEdge: CGRect] {
        guard let carryEdgeInsets else { return [:] }
        let frame = carryEdgeInsets.screen
        let width = carryEdgeInsets.width
        var frames: [PagedStackEdge: CGRect] = [:]
        let leading = CGRect(x: frame.minX, y: frame.minY, width: width, height: frame.height)
        if opensLeadingPage {
            frames[.unopenedLeadingPage] = leading
        } else if pages.indices.contains(page - 1) {
            frames[.page(page - 1)] = leading
        }
        let lastPage = pages.count - (halves ? 2 : 1)
        if page < lastPage {
            frames[.page(page + 1)] = CGRect(x: frame.maxX - width, y: frame.minY,
                                              width: width, height: frame.height)
        }
        return frames
    }

    /// Tapping a visible peek turns to its page. A neighbour without a peek has its edge in the screen's margin.
    @ViewBuilder private func edge(to other: Int, leading: Bool, strip: PageStrip) -> some View {
        if let onTurn, pages.indices.contains(other) {
            let peek = strip.visiblePeek(of: other, showing: page)
            let margin = leading || peek == 0 ? edgeInset : 0
            Color.clear
                .frame(width: peek + margin)
                .contentShape(Rectangle())
                .onTapGesture { if peek > 0 { onTurn(other) } }
                .accessibilityElement()
                .accessibilityLabel(edgeLabel(pages[other]))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onTurn(other) }
                .accessibilityIdentifier("today.pageEdge")
                .offset(x: leading ? -margin : margin)
        }
    }
}
