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

extension UIColor {
    /// `#RRGGBB` or `#RRGGBBAA`.
    convenience init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6 || text.count == 8, let value = UInt64(text, radix: 16) else { return nil }
        let hasAlpha = text.count == 8
        let r = CGFloat((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let g = CGFloat((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let b = CGFloat((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let a = hasAlpha ? CGFloat(value & 0xFF) / 255 : 1
        self.init(red: r, green: g, blue: b, alpha: a)
    }

    /// `#RRGGBB` in sRGB. Colors from the system picker may be Display P3 / extended range, whose
    /// components fall outside 0…1; they are converted and clamped, so the text always parses back.
    var hexString: String {
        let srgb = CGColorSpace(name: CGColorSpace.sRGB).flatMap {
            cgColor.converted(to: $0, intent: .defaultIntent, options: nil)
        }
        let components = srgb?.components ?? cgColor.components ?? [0, 0, 0]
        let rgb = components.count >= 3 ? Array(components.prefix(3)) : Array(repeating: components.first ?? 0, count: 3)
        let bytes = rgb.map { Int((min(max($0, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", bytes[0], bytes[1], bytes[2])
    }
}

extension Color {
    init(hex: String) { self.init(uiColor: UIColor(hex: hex) ?? .systemGray) }
}
