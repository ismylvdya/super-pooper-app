import SwiftUI

/// Small capsule label: icon and/or text on a tertiary fill.
struct Chip: View {
    @Environment(\.tokens) private var tokens
    var icon: Icon?
    var text: String?
    var tint: Color?
    var isOn = true

    var body: some View {
        HStack(spacing: tokens.space(.chipIconGap)) {
            if let icon { IconGlyph(icon, font: .chip) }
            if let text { Text(text).lineLimit(1) }
        }
        .font(tokens.font(.chip))
        .foregroundStyle(isOn ? (tint ?? tokens.color(.secondaryText)) : tokens.color(.tertiaryText))
        .chipCapsule(tokens.color(.chipBackground))
    }
}

extension Chip {
    /// The width of a chip with an icon only, from the icon's size in the chip font: for a layout that needs it
    /// before any chip is drawn (the page peek).
    @MainActor
    static func width(of icon: Icon, tokens: DesignTokens, icons: IconSet, scale: CGFloat) -> CGFloat {
        IconGlyph.size(of: icon, font: tokens.uiFont(.chip), tokens: tokens, icons: icons, scale: scale).width
            + ChipCapsule.standard.horizontalPadding(tokens) * 2
    }
}
