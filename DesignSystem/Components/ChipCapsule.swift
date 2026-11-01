import SwiftUI

/// The capsule a chip-like label sits in — a row's chip, an all-day event's bar, the pool's "+N more", a toggle chip —
/// and how far its content keeps from the edges.
enum ChipCapsule {
    /// A row's chip, an all-day bar, a counter.
    case standard
    /// A toggle chip on a page.
    case large

    func horizontalPadding(_ tokens: DesignTokens) -> CGFloat {
        switch self {
        case .standard: tokens.space(.chipHorizontal)
        case .large: tokens.space(.toggleChipHorizontal)
        }
    }

    func verticalPadding(_ tokens: DesignTokens) -> CGFloat {
        switch self {
        case .standard: tokens.space(.chipVertical)
        case .large: tokens.space(.toggleChipVertical)
        }
    }
}

extension View {
    /// The content in a chip's capsule filled with `fill`, rounded by half its height like the row plates around it.
    func chipCapsule<Fill: ShapeStyle>(_ fill: Fill, _ capsule: ChipCapsule = .standard) -> some View {
        chipInsets(capsule).background(fill, in: Capsule())
    }

    /// The content as far from the edges as in a chip's capsule, for a capsule the system look draws (`SystemLook`).
    func chipInsets(_ capsule: ChipCapsule = .standard) -> some View {
        modifier(ChipInsets(capsule: capsule))
    }
}

private struct ChipInsets: ViewModifier {
    @Environment(\.tokens) private var tokens
    let capsule: ChipCapsule

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, capsule.horizontalPadding(tokens))
            .padding(.vertical, capsule.verticalPadding(tokens))
    }
}
