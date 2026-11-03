import SwiftUI

/// Where the pages of a `PagedStack` are: each page takes the width its neighbours' peeks leave. A page whose peek is
/// zero leaves nothing in sight: its neighbours keep their full width, and it stands at least `edgeInset` away so it
/// stays beyond the screen's edge. Places are counted from the `home` page's start, so pages added before it (the
/// backlog pages left of the pool) move nothing that is already shown.
struct PageStrip: Equatable {
    let count: Int
    let width: CGFloat
    let spacing: CGFloat
    let peeks: [CGFloat]
    var edgeInset: CGFloat = 0
    var home = 0

    func peek(of index: Int) -> CGFloat { peeks.indices.contains(index) ? peeks[index] : 0 }

    /// The gap between page `index` and the next one.
    func gap(after index: Int) -> CGFloat {
        peek(of: index) > 0 && peek(of: index + 1) > 0 ? spacing : max(spacing, edgeInset)
    }

    func width(of index: Int) -> CGFloat {
        max(width - leadingRoom(of: index) - trailingRoom(of: index), 1)
    }

    /// Where page `index` starts, from the start of the home page.
    func origin(of index: Int) -> CGFloat {
        let step = { (page: Int) in self.width(of: page) + self.gap(after: page) }
        if index >= home { return (home..<index).reduce(0) { $0 + step($1) } }
        return -(index..<home).reduce(0) { $0 + step($1) }
    }

    /// The strip's offset that shows page `index` with its leading neighbour's peek before it.
    func offset(showing index: Int) -> CGFloat {
        let index = min(max(index, 0), max(count - 1, 0))
        return leadingRoom(of: index) - origin(of: index)
    }

    /// The part of the stack the leading neighbour keeps while `index` is shown: its peek and the gap.
    private func leadingRoom(of index: Int) -> CGFloat {
        index > 0 && peek(of: index - 1) > 0 ? peek(of: index - 1) + gap(after: index - 1) : 0
    }

    private func trailingRoom(of index: Int) -> CGFloat {
        index < count - 1 && peek(of: index + 1) > 0 ? peek(of: index + 1) + gap(after: index) : 0
    }
}
