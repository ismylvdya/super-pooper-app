import SwiftUI

/// Colored circle of an external source (calendar, reminders list).
struct SourceDot: View {
    @Environment(\.tokens) private var tokens
    let hex: String
    var size: CGFloat?

    var body: some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: size ?? tokens.size(.sourceDot), height: size ?? tokens.size(.sourceDot))
    }
}
