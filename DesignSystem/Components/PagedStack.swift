import SwiftUI
import UniformTypeIdentifiers

/// Blocks as pages of almost the full width, side by side: the shown page leaves its neighbours' `peeks` visible
/// at the edges (each page has its own: how much of it stays in sight while another page is shown), and tapping
/// that edge (or dragging something onto it) turns to it. `drag` moves the pages with a finger that is turning
/// them (clamped at the first and the last page). `edgeInset` is how far the screen's edge is beyond the stack: a
/// page behind the leading edge shows there too.
struct PagedStack<Block: View>: View {
    let slots: [ScreenLayout.Slot]
    let spacing: CGFloat
    let peeks: [CGFloat]
    var edgeInset: CGFloat = 0
    var page = 0
    var drag: CGFloat = 0
    var onTurn: ((Int) -> Void)?
    @ViewBuilder let block: (TodayBlockID) -> Block

    var body: some View {
        GeometryReader { geometry in
            let pages = PageStrip(count: slots.count, width: geometry.size.width, spacing: spacing, peeks: peeks)
            let offset = min(max(pages.offset(showing: page) + drag, pages.offset(showing: slots.count - 1)), 0)
            HStack(alignment: .top, spacing: spacing) {
                ForEach(Array(slots.enumerated()), id: \.element.block) { index, slot in
                    block(slot.block).frame(width: pages.width(of: index), height: geometry.size.height)
                        .zIndex(LiftLayer.block(at: index, of: slots.count))
                }
            }
            .offset(x: offset)
            // The edge belongs to the screen, not to the moving strip of pages.
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
            .overlay(alignment: page == 0 ? .trailing : .leading) {
                if let onTurn, slots.count > 1 {
                    let other = page == 0 ? 1 : page - 1
                    // The visible edge of the other page turns to it instead of acting on what it shows: a tap, or a
                    // drag reaching it.
                    Color.clear
                        .frame(width: max(pages.peek(of: other) + (page == 0 ? 0 : edgeInset), 0))
                        .padding(.leading, page == 0 ? 0 : -edgeInset)
                        .contentShape(Rectangle())
                        .onTapGesture { onTurn(other) }
                        .onDrop(of: [.text], delegate: PageEdgeDrop { onTurn(other) })
                        .accessibilityElement()
                        .accessibilityLabel(Text(page == 0 ? "today.page.timeline" : "today.page.pool"))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("today.pageEdge")
                }
            }
        }
    }
}

/// A drag that reaches the edge of the other page turns to it; nothing is dropped there.
private struct PageEdgeDrop: DropDelegate {
    let turn: () -> Void

    func dropEntered(info: DropInfo) {
        turn()
    }

    func performDrop(info: DropInfo) -> Bool {
        false
    }
}
