import SwiftUI
import UniformTypeIdentifiers

/// Where the pages of a `PagedStack` are: each page takes the width its neighbours' peeks leave.
struct PageStrip: Equatable {
    let count: Int
    let width: CGFloat
    let spacing: CGFloat
    let peeks: [CGFloat]

    func peek(of index: Int) -> CGFloat { peeks.indices.contains(index) ? peeks[index] : 0 }

    func width(of index: Int) -> CGFloat {
        let before = index > 0 ? peek(of: index - 1) + spacing : 0
        let after = index < count - 1 ? peek(of: index + 1) + spacing : 0
        return max(width - before - after, 1)
    }

    /// The strip's offset that shows page `index` with its leading neighbour's peek before it.
    func offset(showing index: Int) -> CGFloat {
        let index = min(max(index, 0), max(count - 1, 0))
        let start = (0..<index).reduce(0) { $0 + width(of: $1) + spacing }
        let before = index > 0 ? peek(of: index - 1) + spacing : 0
        return before - start
    }
}
