import SwiftUI

/// A group of bar buttons in the glass capsule the system draws around them upright; lying sideways, a column of them.
struct BarButtonGroup<Content: View>: View {
    @Environment(\.tokens) private var tokens
    let axis: Axis
    @ViewBuilder let content: () -> Content

    var body: some View {
        let layout = axis == .horizontal ? AnyLayout(HStackLayout(spacing: tokens.bar(.barButtonGap)))
            : AnyLayout(VStackLayout(spacing: tokens.bar(.barButtonGap)))
        layout { content() }
            .buttonStyle(.plain)
            .foregroundStyle(tokens.color(.primaryText))
            .systemLook(.barCapsule)
    }
}
