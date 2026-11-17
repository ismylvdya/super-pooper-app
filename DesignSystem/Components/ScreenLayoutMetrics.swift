import SwiftUI

/// The gap between a layout's blocks, read from the tokens (how much of a page stays in sight beside another is the
/// settings', `PagePeeks`).
struct ScreenLayoutMetrics {
    let tokens: DesignTokens

    func spacing(of layout: ScreenLayout) -> CGFloat {
        SpacingToken(rawValue: layout.spacing).map(tokens.space) ?? 0
    }
}

extension EnvironmentValues {
    var screenLayoutMetrics: ScreenLayoutMetrics {
        ScreenLayoutMetrics(tokens: tokens)
    }
}
