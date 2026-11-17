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
    /// closes the group, a lift of exactly its size and shape, and its place reported for the backing — `index` of
    /// `count` rows in the group's own order. The text starts as far from the left as on the plates elsewhere;
    /// `vertical` is the inset above and below it (nil: a list row's), `separatorIndent` how much further right than
    /// the text the separator starts (past an icon column).
    func listGroupRow(group: String, id: String, index: Int, count: Int, frames: ListGroupFrames,
                      vertical: CGFloat? = nil, separatorIndent: CGFloat = 0) -> some View {
        modifier(ListGroupRow<EmptyView>(group: group, id: id, index: index, count: count, frames: frames, vertical: vertical,
                                         separatorIndent: separatorIndent, menu: nil))
    }

    /// A row of a group with a long-press menu: the menu lifts the row's plate, and so does a drag from it. `tint` (a
    /// high-priority task's soft red, as in the pool) fills the row's whole cell at rest, square but at the group's ends,
    /// as one with the group; lifted, the row is cut to its plate's outline, so it is round on all four corners then.
    /// `started`: a started task's look (`StartedLayout.shown(for:)`), its circle standing `separatorIndent` in.
    func listGroupRow<Menu: View>(group: String, id: String, index: Int, count: Int, frames: ListGroupFrames,
                                  vertical: CGFloat? = nil, separatorIndent: CGFloat = 0, tint: Color? = nil,
                                  started: StartedLayout? = nil, @ViewBuilder menu: () -> Menu) -> some View {
        modifier(ListGroupRow(group: group, id: id, index: index, count: count, frames: frames, vertical: vertical,
                              separatorIndent: separatorIndent, tint: tint, started: started, menu: menu()))
    }

    /// The backing plates of the list's groups, drawn behind it; they follow the list's scrolling, not a drag.
    func listGroupBacking(_ frames: ListGroupFrames) -> some View {
        modifier(ListGroupBackingPlacing(frames: frames))
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

private struct ListGroupRow<Menu: View>: ViewModifier {
    @Environment(\.tokens) private var tokens
    @Environment(\.displayScale) private var displayScale
    let group: String
    let id: String
    let index: Int
    let count: Int
    let frames: ListGroupFrames
    let vertical: CGFloat?
    let separatorIndent: CGFloat
    var tint: Color? = nil
    var started: StartedLayout? = nil
    let menu: Menu?

    func body(content: Content) -> some View {
        let inset = tokens.space(.plateInner)
        content
            .padding(.horizontal, inset)
            .padding(.vertical, vertical ?? tokens.space(.listRowVertical))
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(ListRowStarted(started: started, indent: separatorIndent, inset: inset, cellShape: cellShape, tint: tint))
            .plate(.group)
            .overlay(alignment: .bottom) {
                if index < count - 1 {
                    Rectangle().fill(tokens.color(.listSeparator)).frame(height: 1 / displayScale).padding(.leading, inset + separatorIndent)
                }
            }
            .contentShape(Rectangle())
            .plateLift(.group)
            .modifier(ListGroupRowMenu(menu: menu))
            // A drag lifts the whole cell, menu and all: UIKit gets the plate's outline for it, so no lift falls back to
            // a shape of the system's (on iOS 26 a tall row would lift with corners of half its height).
            .listCellLift(tokens.plateShape(.group))
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                frames.set(.init(frame: frame, index: index, count: count), group: group, id: id)
            }
            // A new place in the group, or another group, does not always move the row.
            .onChange(of: [index, count]) { frames.setPlace(index: index, count: count, group: group, id: id) }
            .onChange(of: group) { old, new in frames.move(id, from: old, to: new, index: index, count: count) }
            // A list may hide and show a row again without moving it (no new frame comes then): the row keeps its place.
            .onAppear { frames.setVisible(true, group: group, id: id) }
            .onDisappear { frames.setVisible(false, group: group, id: id) }
            .listGroupSpacer()
    }

    /// The row's cell as a piece of its group's plate: rounded only where it starts or ends the group.
    private var cellShape: UnevenRoundedRectangle {
        let radius = tokens.plateRadius(.group)
        return UnevenRoundedRectangle(topLeadingRadius: index == 0 ? radius : 0, bottomLeadingRadius: index == count - 1 ? radius : 0,
                                      bottomTrailingRadius: index == count - 1 ? radius : 0, topTrailingRadius: index == 0 ? radius : 0,
                                      style: .circular)
    }
}

private struct ListGroupRowMenu<Menu: View>: ViewModifier {
    let menu: Menu?

    func body(content: Content) -> some View {
        if let menu {
            content.contextMenu { menu }
        } else {
            content
        }
    }
}

/// The backing behind the list, and where the list stands for it: its span, its sides inside the margins, its scroll.
private struct ListGroupBackingPlacing: ViewModifier {
    @Environment(\.tokens) private var tokens
    let frames: ListGroupFrames

    func body(content: Content) -> some View {
        content
            .background { ListGroupBacking(frames: frames) }
            .onGeometryChange(for: ClosedRange<CGFloat>.self) { proxy in
                let frame = proxy.frame(in: .global)
                return frame.minY...frame.maxY
            } action: { frames.setViewport($0) }
            .onGeometryChange(for: ClosedRange<CGFloat>.self) { proxy in
                let frame = proxy.frame(in: .global)
                return frame.minX...frame.maxX
            } action: { frames.setSides($0, margin: tokens.space(.screenHorizontal)) }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, offset in
                frames.setScrollOffset(offset)
            }
    }
}

private struct ListGroupBacking: View {
    @Environment(\.tokens) private var tokens
    let frames: ListGroupFrames

    var body: some View {
        GeometryReader { proxy in
            let list = proxy.frame(in: .global)
            // A side left open (its row out of sight) reaches past the whole screen, bars included (rows scroll on under
            // them), so no corner and no end shows there.
            let overhang = list.height + list.minY
            ForEach(frames.rows.keys.sorted(), id: \.self) { group in
                if let plate = frames.plate(of: group, overhang: overhang) {
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
