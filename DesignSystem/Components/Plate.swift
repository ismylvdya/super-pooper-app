import SwiftUI

/// The rounded group background.
struct Plate<Content: View>: View {
    @Environment(\.tokens) private var tokens
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.plateRowGap)) { content }
            .padding(tokens.space(.plateInner))
            .frame(maxWidth: .infinity, alignment: .leading)
            .plate(.group)
    }
}
