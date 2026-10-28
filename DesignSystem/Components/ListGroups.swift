import SwiftUI

/// A list whose rows stand together as groups (rounded only at a group's top and bottom: This week, Lists lists,
/// Habits, Routines). Behind every group lies its backing — one plate of the group's shape, in the rows' color — and
/// every row is a plate of its own on top of it, rounded by min(the group's corner radius, half its height). At
/// rest the two read as one plate. A row lifted by a long press or a drag is exactly that row (from the row above to
/// the row below, from the list's left edge to its right) and leaves the backing showing in its shape; rows that
/// move aside while dragging uncover it too.
///
/// The list is a plain `List` with no insets or row backgrounds of its own (`listGroupRow`), so a row is exactly
/// its cell; the backing is drawn behind the list from where the rows report they are (`listGroupBacking`).

/// Where the rows of the groups stand on screen. Written by the rows, read only by the backing: scrolling redraws
/// the backing, not the list.
@MainActor
@Observable
final class ListGroupFrames {
    struct Row: Equatable {
        var frame: CGRect
        var isFirst: Bool
        var isLast: Bool
        /// On screen now; a row out of sight keeps its last place but does not bound the backing.
        var isVisible = true
    }

    private(set) var rows: [String: [String: Row]] = [:]

    func set(_ row: Row?, group: String, id: String) {
        guard rows[group]?[id] != row else { return }
        rows[group, default: [:]][id] = row
    }

    func setVisible(_ isVisible: Bool, group: String, id: String) {
        guard var row = rows[group]?[id], row.isVisible != isVisible else { return }
        row.isVisible = isVisible
        rows[group]?[id] = row
    }
}

/// The backing of one group from its rows on screen: from the first row's top, as tall as all its rows together —
/// so a row dragged away (the last one too) never shrinks it — and at least to the last row's bottom. A first or last
/// row out of sight (a list only lays out what shows) leaves that side open past `visible`.
enum ListGroupGeometry {
    static func plate(of rows: [ListGroupFrames.Row], visible: ClosedRange<CGFloat>, overhang: CGFloat) -> CGRect? {
        let shown = rows.filter(\.isVisible)
        guard let any = shown.first else { return nil }
        let first = shown.first { $0.isFirst }
        let last = shown.first { $0.isLast }
        let top = first?.frame.minY ?? visible.lowerBound - overhang
        var bottom = last?.frame.maxY ?? visible.upperBound + overhang
        if first != nil, last != nil { bottom = max(bottom, top + shown.map(\.frame.height).reduce(0, +)) }
        guard bottom > top else { return nil }
        return CGRect(x: any.frame.minX, y: top, width: any.frame.width, height: bottom - top)
    }
}

extension View {
    /// One row of a group (see `ListGroupFrames`): its own plate, a separator under it unless it closes the group,
    /// a lift of exactly its size and shape, and its place reported for the backing.
    func listGroupRow(group: String, id: String, isFirst: Bool, isLast: Bool, frames: ListGroupFrames,
                      separatorInset: CGFloat) -> some View {
        modifier(ListGroupRow(group: group, id: id, isFirst: isFirst, isLast: isLast, frames: frames, separatorInset: separatorInset))
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
    let separatorInset: CGFloat

    func body(content: Content) -> some View {
        let shape = PlateShape(cornerRadius: tokens.radius(.plate))
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tokens.color(.plateBackground), in: shape)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle().fill(tokens.color(.listSeparator)).frame(height: 1 / displayScale).padding(.leading, separatorInset)
                }
            }
            .contentShape(Rectangle())
            .contentShape(.contextMenuPreview, shape)
            .contentShape(.dragPreview, shape)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                frames.set(.init(frame: frame, isFirst: isFirst, isLast: isLast), group: group, id: id)
            }
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
            let overhang = tokens.radius(.plate) * 2
            ForEach(frames.rows.keys.sorted(), id: \.self) { group in
                if let plate = ListGroupGeometry.plate(of: Array(frames.rows[group]?.values ?? [:].values),
                                                       visible: list.minY...list.maxY, overhang: overhang) {
                    PlateShape(cornerRadius: tokens.radius(.plate))
                        .fill(tokens.color(.plateBackground))
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

/// A group's title, standing in the list as a row of its own (so rows can be dragged across it), as far from the
/// left as the rows' text and as high above its group as section headers on the plates elsewhere.
struct ListGroupHeader: View {
    @Environment(\.tokens) private var tokens
    let title: Text

    var body: some View {
        title
            .font(tokens.font(.sectionHeader))
            .foregroundStyle(tokens.color(.tertiaryText))
            .padding(.horizontal, tokens.space(.plateInner))
            .padding(.top, tokens.space(.groupGap))
            .padding(.bottom, tokens.space(.headerToPlate))
            .frame(maxWidth: .infinity, alignment: .leading)
            .listGroupSpacer()
    }
}

/// The space above a group without a title.
struct ListGroupGap: View {
    @Environment(\.tokens) private var tokens

    var body: some View {
        Color.clear.frame(height: tokens.space(.groupGap)).listGroupSpacer()
    }
}

/// A hint under a group, as under the plates elsewhere.
struct ListGroupFooter: View {
    @Environment(\.tokens) private var tokens
    let text: Text

    var body: some View {
        text
            .font(tokens.font(.hint))
            .foregroundStyle(tokens.color(.secondaryText))
            .padding(.horizontal, tokens.space(.plateInner))
            .padding(.top, tokens.space(.hintToPlate))
            .frame(maxWidth: .infinity, alignment: .leading)
            .listGroupSpacer()
    }
}
