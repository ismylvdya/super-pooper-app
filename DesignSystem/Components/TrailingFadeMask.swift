import SwiftUI

/// Opaque on the left, transparent over the last `width` points: content dissolves at the edge.
struct TrailingFadeMask: View {
    let width: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: width)
        }
    }
}
