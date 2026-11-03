import SwiftUI

/// The gap between a layout's blocks and how much of each page stays in sight beside another one, read from the tokens.
@MainActor
struct ScreenLayoutMetrics {
    let tokens: DesignTokens
    let icons: IconSet
    let chipOrder: [RowChipKind]
    let scale: CGFloat

    func spacing(of layout: ScreenLayout) -> CGFloat {
        SpacingToken(rawValue: layout.spacing).map(tokens.space) ?? 0
    }

    /// A chip peek is counted from the screen's edge: the row plate's right inset and that part of the rows' last chip
    /// (in the user's chip order).
    func peek(of slot: ScreenLayout.Slot, in layout: ScreenLayout, edgeInset: CGFloat) -> CGFloat {
        if let part = slot.peekChip {
            let chip = chipOrder.last.map { Chip.width(of: $0.icon, tokens: tokens, icons: icons, scale: scale) } ?? 0
            return tokens.rowPlateTrailingInset + chip * part - edgeInset
        }
        return layout.peek.flatMap(SizeToken.init(rawValue:)).map(tokens.size) ?? 0
    }
}

extension EnvironmentValues {
    @MainActor var screenLayoutMetrics: ScreenLayoutMetrics {
        ScreenLayoutMetrics(tokens: tokens, icons: icons, chipOrder: chipOrder, scale: displayScale)
    }
}
