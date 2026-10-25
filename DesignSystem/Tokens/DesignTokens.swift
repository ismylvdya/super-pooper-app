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

    var animation: Animation { .easeInOut(duration: duration(.animation)) }

    /// The user's appearance settings over the bundled tokens: colors and the opacity of done/past items.
    func applying(_ settings: AppSettings, limits: RulesConfig.Limits) -> DesignTokens {
        let colored = overridingColors(settings.colors)
        let past = min(max(settings.appearance.pastOpacity, limits.pastOpacity.min), limits.pastOpacity.max)
        return DesignTokens(spacing: spacing, radius: radius, size: size,
                            opacity: colored.opacity.replacing([.past: past]),
                            duration: duration, font: font, color: colored.color)
    }

    /// User color choices (settings) over the bundled palette; unknown names and bad hex are ignored.
    func overridingColors(_ hexByName: [String: String]) -> DesignTokens {
        var overrides: [ColorToken: ColorSpec] = [:]
        for (name, hex) in hexByName {
            // The interface is black / white; an accent chosen in an older version is ignored.
            guard let token = ColorToken(rawValue: name), token != .accent, UIColor(hex: hex) != nil else { continue }
            overrides[token] = ColorSpec(light: hex, dark: hex, system: nil)
        }
        guard !overrides.isEmpty else { return self }
        return DesignTokens(spacing: spacing, radius: radius, size: size, opacity: opacity, duration: duration,
                            font: font, color: color.replacing(overrides))
    }
}

/// `{"style": "title3", "weight": "bold", "design": "rounded"}` or `{"size": 34, …}`.
struct FontSpec: Decodable, Sendable {
    let style: String?
    let size: Double?
    let weight: String?
    let design: String?

    var font: Font {
        let weight = FontSpec.weights[self.weight ?? "regular"] ?? .regular
        let design = FontSpec.designs[self.design ?? "default"] ?? .default
        if let size { return .system(size: size, weight: weight, design: design) }
        return .system(FontSpec.styles[style ?? "body"] ?? .body, design: design, weight: weight)
    }

    var uiFont: UIFont {
        let base: UIFont
        let uiWeight = FontSpec.uiWeights[weight ?? "regular"] ?? .regular
        if let size {
            base = .systemFont(ofSize: size, weight: uiWeight)
        } else {
            let style = FontSpec.uiStyles[style ?? "body"] ?? .body
            base = .systemFont(ofSize: UIFont.preferredFont(forTextStyle: style).pointSize, weight: uiWeight)
        }
        guard design == "rounded", let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: base.pointSize)
    }

    private static let weights: [String: Font.Weight] = [
        "regular": .regular, "medium": .medium, "semibold": .semibold, "bold": .bold, "heavy": .heavy, "light": .light,
    ]
    private static let uiWeights: [String: UIFont.Weight] = [
        "regular": .regular, "medium": .medium, "semibold": .semibold, "bold": .bold, "heavy": .heavy, "light": .light,
    ]
    private static let designs: [String: Font.Design] = ["default": .default, "rounded": .rounded, "monospaced": .monospaced]
    private static let styles: [String: Font.TextStyle] = [
        "largeTitle": .largeTitle, "title": .title, "title2": .title2, "title3": .title3, "headline": .headline,
        "body": .body, "callout": .callout, "subheadline": .subheadline, "footnote": .footnote,
        "caption": .caption, "caption2": .caption2,
    ]
    private static let uiStyles: [String: UIFont.TextStyle] = [
        "largeTitle": .largeTitle, "title": .title1, "title2": .title2, "title3": .title3, "headline": .headline,
        "body": .body, "callout": .callout, "subheadline": .subheadline, "footnote": .footnote,
        "caption": .caption1, "caption2": .caption2,
    ]
}

/// `{"light": "#RRGGBB", "dark": "#RRGGBB"}` (each color picked per theme) or `{"system": "label"}`.
struct ColorSpec: Decodable, Sendable {
    init(light: String?, dark: String?, system: String?) {
        self.light = light
        self.dark = dark
        self.system = system
    }

    let light: String?
    let dark: String?
    let system: String?

    var color: Color { Color(uiColor: uiColor) }

    var uiColor: UIColor {
        if let system, let color = ColorSpec.systemColors[system] { return color }
        let light = UIColor(hex: light ?? "#000000") ?? .label
        let dark = UIColor(hex: dark ?? self.light ?? "#FFFFFF") ?? light
        return UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }

    private static let systemColors: [String: UIColor] = [
        "label": .label, "secondaryLabel": .secondaryLabel, "tertiaryLabel": .tertiaryLabel,
        "systemBackground": .systemBackground, "secondarySystemBackground": .secondarySystemBackground,
        "systemGroupedBackground": .systemGroupedBackground,
        "secondarySystemGroupedBackground": .secondarySystemGroupedBackground,
        "tertiarySystemFill": .tertiarySystemFill, "secondarySystemFill": .secondarySystemFill,
        "quaternarySystemFill": .quaternarySystemFill, "separator": .separator, "systemRed": .systemRed,
    ]
}

extension Color {
    init(hex: String) { self.init(uiColor: UIColor(hex: hex) ?? .systemGray) }

    /// Hex of a resolved token color (for components that take hex strings).
    var hexValue: String { UIColor(self).hexString }
}
