import SwiftUI

/// A list whose rows stand together as groups (rounded only at a group's top and bottom: Soon, Lists lists,
/// Habits, Routines). Behind every group lies its backing — one plate of the group's shape, in the rows' color — and
/// every row is a plate of its own on top of it, rounded by min(the group's corner radius, half its height). At
/// rest the two read as one plate. A row lifted by a long press or a drag is exactly that row (from the row above to
/// the row below, from the list's left edge to its right) and leaves the backing showing in its shape; rows that
/// move aside while dragging uncover it too.
///
/// The list is a plain `List` with no insets or row backgrounds of its own (`listGroupRow`), so a row is exactly
/// its cell; the backing is drawn behind the list from where the rows report they are (`listGroupBacking`).

extension View {
    /// One row of a group (see `ListGroupFrames`): its own plate with the rows' insets, a separator under it unless it
    /// closes the group, a lift of exactly its size and shape, and its place reported for the backing. The text starts
    /// as far from the left as on the plates elsewhere; `vertical` is the inset above and below it (nil: a list row's),
    /// `separatorIndent` how much further right than the text the separator starts (past an icon column).
    func listGroupRow(group: String, id: String, isFirst: Bool, isLast: Bool, frames: ListGroupFrames,
                      vertical: CGFloat? = nil, separatorIndent: CGFloat = 0) -> some View {
        modifier(ListGroupRow(group: group, id: id, isFirst: isFirst, isLast: isLast, frames: frames, vertical: vertical,
                              separatorIndent: separatorIndent))
    }

    /// The backing plates of the list's groups, drawn behind it.
    func listGroupBacking(_ frames: ListGroupFrames) -> some View {
        background { ListGroupBacking(frames: frames) }
    }

    /// A row of a grouped list that is not a group's row (a header, a gap, a hint): no insets, background or
    /// separator of the list's own.
    func listGroupSpacer() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    /// The list style the groups need: plain, rows of their own height, the screen margins as the list's own.
    func listGroupStyle() -> some View {
        modifier(ListGroupStyle())
    }
}

private struct ListGroupRow: ViewModifier {
    @Environment(\.tokens) private var tokens
    @Environment(\.displayScale) private var displayScale
    let group: String
    let id: String
    let isFirst: Bool
    let isLast: Bool
    let frames: ListGroupFrames
    let vertical: CGFloat?
    let separatorIndent: CGFloat

    func body(content: Content) -> some View {
        let inset = tokens.space(.plateInner)
        content
            .padding(.horizontal, inset)
            .padding(.vertical, vertical ?? tokens.space(.listRowVertical))
            .frame(maxWidth: .infinity, alignment: .leading)
            .plate(.group)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle().fill(tokens.color(.listSeparator)).frame(height: 1 / displayScale).padding(.leading, inset + separatorIndent)
                }
            }
            .contentShape(Rectangle())
            .plateLift(.group)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                frames.set(.init(frame: frame, isFirst: isFirst, isLast: isLast), group: group, id: id)
            }
            // Becoming the first or the last, or going to another group, does not always move the row.
            .onChange(of: [isFirst, isLast]) { frames.setEnds(isFirst: isFirst, isLast: isLast, group: group, id: id) }
            .onChange(of: group) { old, new in frames.move(id, from: old, to: new, isFirst: isFirst, isLast: isLast) }
            // A list may hide and show a row again without moving it (no new frame comes then): the row keeps its place.
            .onAppear { frames.setVisible(true, group: group, id: id) }
            .onDisappear { frames.setVisible(false, group: group, id: id) }
            .listGroupSpacer()
    }
}

private struct ListGroupBacking: View {
    @Environment(\.tokens) private var tokens
    let frames: ListGroupFrames

    var body: some View {
        GeometryReader { proxy in
            let list = proxy.frame(in: .global)
            // A side left open (its row out of sight) reaches past the visible part by more than the corner, so no
            // rounded corner shows there.
            let overhang = tokens.radius(.plate) * 2
            ForEach(frames.rows.keys.sorted(), id: \.self) { group in
                if let plate = ListGroupGeometry.plate(of: Array(frames.rows[group]?.values ?? [:].values),
                                                       visible: list.minY...list.maxY, overhang: overhang,
                                                       restingTop: frames.restingTops[group]) {
                    Color.clear
                        .plate(.group)
                        .frame(width: plate.width, height: plate.height)
                        .position(x: plate.midX - list.minX, y: plate.midY - list.minY)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ListGroupStyle: ViewModifier {
    @Environment(\.tokens) private var tokens

    func body(content: Content) -> some View {
        content
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)
            .contentMargins(.horizontal, tokens.space(.screenHorizontal), for: .scrollContent)
    }
}
