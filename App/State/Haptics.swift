import UIKit

/// Light and medium taps: an action's own style, or the style of what a tap does (`actions.json` → `haptics`).
@MainActor
enum Haptics {
    static var isEnabled = true
    /// Set by the composition root; without it (previews) nothing plays.
    static var styles: TokenTable<HapticRole, HapticStyle>?

    static func play(_ role: HapticRole) {
        play(styles?[role] ?? .none)
    }

    static func play(_ style: HapticStyle) {
        guard isEnabled else { return }
        switch style {
        case .none: return
        case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}
