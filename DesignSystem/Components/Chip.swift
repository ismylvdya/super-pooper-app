import SwiftUI

/// Small capsule label: icon and/or text on a tertiary fill.
struct Chip: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    var icon: Icon?
    var text: String?
    var tint: Color?
    var isOn = true

    var body: some View {
        HStack(spacing: tokens.space(.chipIconGap)) {
            if let icon { Image(systemName: icons[icon]) }
            if let text { Text(text).lineLimit(1) }
        }
        .font(tokens.font(.chip))
        .foregroundStyle(isOn ? (tint ?? tokens.color(.secondaryText)) : tokens.color(.tertiaryText))
        .chipCapsule(tokens.color(.chipBackground))
    }
}

extension Chip {
    /// The width of a chip with an icon only, from the symbol's size in the chip font: for a layout that needs it
    /// before any chip is drawn (the page peek).
    static func width(of icon: Icon, tokens: DesignTokens, icons: IconSet) -> CGFloat {
        let symbol = UIImage(systemName: icons[icon], withConfiguration: UIImage.SymbolConfiguration(font: tokens.uiFont(.chip)))
        return (symbol?.size.width ?? 0) + ChipCapsule.standard.horizontalPadding(tokens) * 2
    }
}
