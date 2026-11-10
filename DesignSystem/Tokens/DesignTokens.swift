import SwiftUI

/// Design tokens from `tokens.json` (values follow the manifest specs).
struct DesignTokens: Decodable, Sendable {
    let spacing: TokenTable<SpacingToken, Double>
    let radius: TokenTable<RadiusToken, Double>
    let size: TokenTable<SizeToken, Double>
    let ratio: TokenTable<RatioToken, Double>
    let count: TokenTable<CountToken, Int>
    private(set) var opacity: TokenTable<OpacityToken, Double>
    let duration: TokenTable<DurationToken, Double>
    let font: TokenTable<FontToken, FontSpec>
    let glyph: TokenTable<GlyphToken, String>
    let systemBar: SystemBarTokens
    private(set) var color: TokenTable<ColorToken, ColorSpec>
    /// The colors each settings section lets the user pick.
    let editableColors: TokenTable<ColorSettingsGroup, [ColorToken]>
    /// The reader's text size where the tokens are used (`designTokens(_:)`); nil: the phone's own.
    private(set) var dynamicTypeSize: DynamicTypeSize?

    private enum CodingKeys: String, CodingKey { case spacing, radius, size, ratio, count, opacity, duration, font, glyph, systemBar, color, editableColors }

    func space(_ token: SpacingToken) -> CGFloat { CGFloat(spacing[token]) }
    func radius(_ token: RadiusToken) -> CGFloat { CGFloat(radius[token]) }
    func size(_ token: SizeToken) -> CGFloat { CGFloat(size[token]) }
    func ratio(_ token: RatioToken) -> CGFloat { CGFloat(ratio[token]) }
    func count(_ token: CountToken) -> Int { count[token] }
    func opacity(_ token: OpacityToken) -> Double { opacity[token] }
    func duration(_ token: DurationToken) -> Double { duration[token] }
    func font(_ token: FontToken) -> Font { font[token].font(at: traits) }
    func uiFont(_ token: FontToken) -> UIFont { font[token].uiFont(at: traits) }
    /// The token's weight and design at a size given elsewhere (picked in settings, chosen in a widget): used as is.
    func font(_ token: FontToken, size: Double) -> Font { font[token].font(size: size) }
    func uiFont(_ token: FontToken, size: Double) -> UIFont { font[token].uiFont(size: size) }
    /// A length that belongs to a font's text (a label column, its line), grown with the reader's text size as the font is.
    func scaled(_ value: CGFloat, with token: FontToken) -> CGFloat { font[token].scaled(value, at: traits) }
    func bar(_ metric: SystemBarMetric) -> CGFloat { CGFloat(systemBar.metric[metric]) }
    func font(_ token: SystemBarFont) -> Font { systemBar.font[token].font(at: traits) }
    func uiFont(_ token: SystemBarFont) -> UIFont { systemBar.font[token].uiFont(at: traits) }
    func color(_ token: ColorToken) -> Color { color[token].color }
    func uiColor(_ token: ColorToken) -> UIColor { color[token].uiColor }

    var animation: Animation { .easeInOut(duration: duration(.animation)) }

    /// The tokens as measured at a text size: fixed-size fonts and UIKit line heights follow it.
    func measured(at dynamicTypeSize: DynamicTypeSize) -> DesignTokens {
        var tokens = self
        tokens.dynamicTypeSize = dynamicTypeSize
        return tokens
    }

    private var traits: UITraitCollection? {
        dynamicTypeSize.map { UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory($0)) }
    }

    /// A chip's height: its line and its padding.
    var chipHeight: CGFloat { uiFont(.chip).lineHeight + space(.chipVertical) * 2 }

    /// The corner of a task's plate, concentric with its chips: their corner (half their height) plus the distance the
    /// plate keeps from them on the top, bottom and right (half the row's vertical padding).
    var rowPlateRadius: CGFloat { chipHeight / 2 + space(.rowVertical) / 2 }
    /// Where the line from a parent to its subtasks comes down, from the parent's plate's left edge: under the middle of
    /// the first letter of its name (`glyph.subtaskLine`), the name starting the row's leading inset in.
    var subtaskLineX: CGFloat {
        let letter = (glyph[.subtaskLine] as NSString).size(withAttributes: [.font: uiFont(.taskTitle)]).width
        return space(.plateInner) / 2 + letter / 2
    }
    /// How far right a subtask stands of its parent: its plate starts as far right of the line as the parent's is left
    /// of it, so the line stands halfway between them, at every level.
    var subtaskIndent: CGFloat { subtaskLineX * 2 }
    /// How big a started task's circle can be: from a small letter of the name to a one-line plate.
    var startedCircleSizes: ClosedRange<CGFloat> {
        let title = uiFont(.taskTitle)
        return title.xHeight...(title.lineHeight + space(.rowVertical))
    }
    /// The right inset of a row's own plate (pool, widgets).
    var rowPlateTrailingInset: CGFloat {
        // The icons are smaller than the title's line: on a one-line row they stand as far from the right edge as from the top.
        space(.rowVertical) / 2 + max(uiFont(.taskTitle).lineHeight - size(.rowIconHeight), 0) / 2
    }
    /// Where a banner stands: between the navigation bar's round buttons (back, search).
    var bannerPlacement: BannerPlacement {
        BannerPlacement(bar: bar(.navigationBar), button: bar(.uprightBarButton), sideInset: bar(.barSideInset))
    }
    /// The side insets of a timeline slot's plate.
    var slotPlateInset: CGFloat { space(.plateInner) / 2 }

    /// The user's appearance settings over the bundled tokens: colors, the opacity of done/past items and of a habit's open
    /// rings.
    func applying(_ settings: AppSettings, limits: RulesConfig.Limits) -> DesignTokens {
        var tokens = overridingColors(settings.colors)
        if settings.accent.tabBar { tokens.color = tokens.color.replacing([.tabBar: tokens.color[.tabBarPick]]) }
        tokens.opacity = opacity.replacing([.past: limits.pastOpacity.clamped(settings.appearance.pastOpacity),
                                            .habitOpenRing: limits.ringOpacity.clamped(settings.habits.ringOpacity),
                                            .selectionOutline: limits.selectionOutlineOpacity.clamped(settings.pool.selectionOutlineOpacity)])
        return tokens
    }

    /// The widgets' plates: lighter than the app's in the dark, where a widget sits on a dark Home Screen.
    func forWidget() -> DesignTokens {
        var tokens = self
        tokens.color = color.replacing([.plateBackground: color[.widgetPlate]])
        return tokens
    }

    /// The settings key of a token's own color in the dark theme, beside its plain name.
    static func darkColorKey(_ token: ColorToken) -> String { token.rawValue + ".dark" }

    /// User color choices (settings) over the bundled palette: under a token's name its color, in both themes unless the
    /// dark one has its own (`darkColorKey`). Unknown names and bad hex are ignored.
    func overridingColors(_ hexByName: [String: String]) -> DesignTokens {
        var overrides: [ColorToken: ColorSpec] = [:]
        let valid = hexByName.filter { UIColor(hex: $0.value) != nil }
        for token in ColorToken.allCases {
            let own = valid[token.rawValue]
            let dark = valid[Self.darkColorKey(token)]
            guard own != nil || dark != nil else { continue }
            overrides[token] = ColorSpec(light: own ?? color[token].light, dark: dark ?? own ?? color[token].dark)
        }
        var tokens = self
        tokens.color = color.replacing(overrides)
        return tokens
    }
}

extension Color {
    init(hex: String) { self.init(uiColor: UIColor(hex: hex) ?? .systemGray) }

    /// Hex of a resolved token color (for components that take hex strings).
    var hexValue: String { UIColor(self).hexString }
}
