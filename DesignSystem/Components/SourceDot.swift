import SwiftUI

/// Colored circle of an external source (calendar, reminders list).
struct SourceDot: View {
    @Environment(\.tokens) private var tokens
    let hex: String

    var body: some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: tokens.size(.sourceDot), height: tokens.size(.sourceDot))
    }
}
