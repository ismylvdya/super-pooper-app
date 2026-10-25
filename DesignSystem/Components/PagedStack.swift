import SwiftUI
import UniformTypeIdentifiers

/// Blocks as pages of almost the full width, side by side: the shown page leaves `peek` points of its
/// neighbour visible at the edge, and tapping that edge (or dragging something onto it) turns to it. `drag` moves the pages with a finger
/// that is turning them (clamped at the first and the last page).
struct PagedStack<Block: View>: View {
    let slots: [ScreenLayout.Slot]
    let spacing: CGFloat
    let peek: CGFloat
    var page = 0
    var drag: CGFloat = 0
    var onTurn: ((Int) -> Void)?
    @ViewBuilder let block: (TodayBlockID) -> Block

    var body: some View {
        GeometryReader { geometry in
            let pageWidth = max(geometry.size.width - peek - spacing, 1)
            let step = pageWidth - peek
            let travel = step * CGFloat(max(slots.count - 1, 0))
            let offset = min(max(-CGFloat(page) * step + drag, -travel), 0)
            HStack(alignment: .top, spacing: spacing) {
                ForEach(slots, id: \.block) { slot in
                    block(slot.block).frame(width: pageWidth, height: geometry.size.height)
                }
            }
            .offset(x: offset)
            // The edge belongs to the screen, not to the moving strip of pages.
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
            .overlay(alignment: page == 0 ? .trailing : .leading) {
                if let onTurn, slots.count > 1 {
                    // The visible edge of the other page turns to it instead of acting on what it shows.
                    // Not `Color.clear`: a fully clear view is skipped when a drag looks for a drop target.
                    Rectangle()
                        .fill(Color.black.opacity(0.001))
                        .frame(width: peek)
                        .contentShape(Rectangle())
                        .onTapGesture { onTurn(page == 0 ? 1 : 0) }
                        .onDrop(of: [.text], isTargeted: Binding(get: { false }, set: { if $0 { onTurn(page == 0 ? 1 : 0) } })) { _ in false }
                        .accessibilityElement()
                        .accessibilityLabel(Text(page == 0 ? "today.page.timeline" : "today.page.pool"))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("today.pageEdge")
                }
            }
        }
    }
}
