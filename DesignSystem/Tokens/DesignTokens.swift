import SwiftUI

/// Design tokens from `tokens.json` (values follow the manifest specs).
struct DesignTokens: Decodable, Sendable {
    let spacing: TokenTable<SpacingToken, Double>
    let radius: TokenTable<RadiusToken, Double>
    let size: TokenTable<SizeToken, Double>
    let opacity: TokenTable<OpacityToken, Double>
    let duration: TokenTable<DurationToken, Double>
    let font: TokenTable<FontToken, FontSpec>
    let color: TokenTable<ColorToken, ColorSpec>

    func space(_ token: SpacingToken) -> CGFloat { CGFloat(spacing[token]) }
    func radius(_ token: RadiusToken) -> CGFloat { CGFloat(radius[token]) }
    func size(_ token: SizeToken) -> CGFloat { CGFloat(size[token]) }
    func opacity(_ token: OpacityToken) -> Double { opacity[token] }
    func duration(_ token: DurationToken) -> Double { duration[token] }
    func font(_ token: FontToken) -> Font { font[token].font }
    func uiFont(_ token: FontToken) -> UIFont { font[token].uiFont }
    func color(_ token: ColorToken) -> Color { color[token].color }
    func uiColor(_ token: ColorToken) -> UIColor { color[token].uiColor }

    var animation: Animation { .easeInOut(duration: duration(.animation)) }

    /// A chip's height: its line and its padding.
    var chipHeight: CGFloat { uiFont(.chip).lineHeight + space(.chipVertical) * 2 }

    /// The corner of a task's plate, concentric with its chips: their corner (half their height) plus the distance the
    /// plate keeps from them on the top, bottom and right (half the row's vertical padding).
    var rowPlateRadius: CGFloat { chipHeight / 2 + space(.rowVertical) / 2 }
    /// The right inset of a row's own plate (pool, widgets): the chips stand as far from its right edge as from the top.
    var rowPlateTrailingInset: CGFloat { space(.rowVertical) / 2 }
    /// The side insets of a timeline slot's plate.
    var slotPlateInset: CGFloat { space(.plateInner) / 2 }

    /// The user's appearance settings over the bundled tokens: colors and the opacity of done/past items.
    func applying(_ settings: AppSettings, limits: RulesConfig.Limits) -> DesignTokens {
        let colored = overridingColors(settings.colors)
        let past = min(max(settings.appearance.pastOpacity, limits.pastOpacity.min), limits.pastOpacity.max)
        return DesignTokens(spacing: spacing, radius: radius, size: size,
                            opacity: colored.opacity.replacing([.past: past]),
                            duration: duration, font: font, color: colored.color)
    }

    /// The widgets' plates: lighter than the app's in the dark, where a widget sits on a dark Home Screen.
    func forWidget() -> DesignTokens {
        DesignTokens(spacing: spacing, radius: radius, size: size, opacity: opacity, duration: duration, font: font,
                     color: color.replacing([.plateBackground: color[.widgetPlate]]))
    }

    /// User color choices (settings) over the bundled palette; unknown names and bad hex are ignored.
    func overridingColors(_ hexByName: [String: String]) -> DesignTokens {
        var overrides: [ColorToken: ColorSpec] = [:]
        for (name, hex) in hexByName {
            // The interface is black / white; an accent chosen in an older version is ignored.
            guard let token = ColorToken(rawValue: name), token != .accent, UIColor(hex: hex) != nil else { continue }
            overrides[token] = ColorSpec(hex: hex)
        }
        guard !overrides.isEmpty else { return self }
        return DesignTokens(spacing: spacing, radius: radius, size: size, opacity: opacity, duration: duration,
                            font: font, color: color.replacing(overrides))
    }
}

extension Color {
    init(hex: String) { self.init(uiColor: UIColor(hex: hex) ?? .systemGray) }

    /// Hex of a resolved token color (for components that take hex strings).
    var hexValue: String { UIColor(self).hexString }
}
