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
    /// The first pages (the backlog lists): while one of them is shown, both its neighbours stay in sight by
    /// `listPeek`, and while any other is shown, they stay out of it.
    var listCount = 0
    var listPeek: CGFloat = 0
    /// The first lists, not opened yet: nothing of them is in sight beside the last one opened.
    var hiddenLists = 0

    func peek(of index: Int) -> CGFloat { peeks.indices.contains(index) ? peeks[index] : 0 }

    /// The gap between page `index` and the next one.
    func gap(after index: Int) -> CGFloat {
        if index < hiddenLists { return max(spacing, edgeInset) }
        if index < listCount { return spacing }
        return peek(of: index) > 0 && peek(of: index + 1) > 0 ? spacing : max(spacing, edgeInset)
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

    /// How much of page `other` stays in sight while `shown` is shown.
    func visiblePeek(of other: Int, showing shown: Int) -> CGFloat {
        if other < hiddenLists { return 0 }
        return shown < listCount ? listPeek : peek(of: other)
    }

    /// The strip's offset that shows page `index` with its leading neighbour's peek before it.
    func offset(showing index: Int) -> CGFloat {
        let index = min(max(index, 0), max(count - 1, 0))
        return leadingRoom(of: index) - origin(of: index)
    }

    /// The part of the stack the leading neighbour keeps while `index` is shown: its peek and the gap.
    private func leadingRoom(of index: Int) -> CGFloat {
        if index < listCount { return index > hiddenLists ? listPeek + spacing : 0 }
        return index > 0 && peek(of: index - 1) > 0 ? peek(of: index - 1) + gap(after: index - 1) : 0
    }

    private func trailingRoom(of index: Int) -> CGFloat {
        if index < listCount { return index < count - 1 ? listPeek + spacing : 0 }
        return index < count - 1 && peek(of: index + 1) > 0 ? peek(of: index + 1) + gap(after: index) : 0
    }
}
