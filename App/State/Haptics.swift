import UIKit

/// Light and medium taps for actions (style comes from the action registry).
@MainActor
enum Haptics {
    static var isEnabled = true

    static func play(_ style: HapticStyle) {
        guard isEnabled else { return }
        switch style {
        case .none: return
        case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}
