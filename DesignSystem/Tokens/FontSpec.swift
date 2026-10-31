import SwiftUI

/// `{"style": "title3", "weight": "bold", "design": "rounded"}` or `{"size": 34, "relativeTo": "largeTitle", …}`. A text
/// style follows the reader's text size by itself; a fixed size grows and shrinks with it as its `relativeTo` style does
/// (`UIFontMetrics`). Every name is checked when tokens.json loads: a misspelt weight, style, design or key is a config
/// error, not a silent regular body font.
struct FontSpec: Decodable, Sendable {
    let style: Style
    let size: Double?
    /// The text style a fixed size scales with.
    let relativeTo: Style?
    let weight: Weight
    let design: Design

    private enum CodingKeys: String, CodingKey { case style, size, relativeTo, weight, design }

    init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        style = try container.decodeIfPresent(Style.self, forKey: .style) ?? .body
        size = try container.decodeIfPresent(Double.self, forKey: .size)
        weight = try container.decodeIfPresent(Weight.self, forKey: .weight) ?? .regular
        design = try container.decodeIfPresent(Design.self, forKey: .design) ?? .default
        relativeTo = try container.decodeIfPresent(Style.self, forKey: .relativeTo)
        if let size, size <= 0 {
            throw DecodingError.dataCorruptedError(forKey: .size, in: container, debugDescription: "a font size must be positive")
        }
        if size != nil, relativeTo == nil {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "a fixed size needs \"relativeTo\": the text style it scales with"))
        }
        if size == nil, relativeTo != nil {
            throw DecodingError.dataCorruptedError(forKey: .relativeTo, in: container, debugDescription: "only a fixed size scales relative to a style")
        }
    }

    /// The font at the reader's text size (`traits`; nil: the phone's own).
    func font(at traits: UITraitCollection?) -> Font {
        if let size { return .system(size: scaled(size, at: traits), weight: weight.font, design: design.font) }
        return .system(style.font, design: design.font, weight: weight.font)
    }

    func uiFont(at traits: UITraitCollection?) -> UIFont {
        let pointSize = size.map { scaled($0, at: traits) }
            ?? UIFont.preferredFont(forTextStyle: style.uiFont, compatibleWith: traits).pointSize
        let base = UIFont.systemFont(ofSize: pointSize, weight: weight.uiFont)
        guard let systemDesign = design.uiFont, let descriptor = base.fontDescriptor.withDesign(systemDesign) else { return base }
        return UIFont(descriptor: descriptor, size: pointSize)
    }

    /// A length drawn next to this font (a column for its digits, the line it sits in), grown as the font grows.
    func scaled(_ value: CGFloat, at traits: UITraitCollection?) -> CGFloat {
        UIFontMetrics(forTextStyle: (relativeTo ?? style).uiFont).scaledValue(for: value, compatibleWith: traits)
    }

    enum Weight: String, ConfigName {
        case light, regular, medium, semibold, bold, heavy

        var font: Font.Weight {
            switch self {
            case .light: .light
            case .regular: .regular
            case .medium: .medium
            case .semibold: .semibold
            case .bold: .bold
            case .heavy: .heavy
            }
        }

        var uiFont: UIFont.Weight {
            switch self {
            case .light: .light
            case .regular: .regular
            case .medium: .medium
            case .semibold: .semibold
            case .bold: .bold
            case .heavy: .heavy
            }
        }
    }

    enum Design: String, ConfigName {
        case `default`, rounded, monospaced

        var font: Font.Design {
            switch self {
            case .default: .default
            case .rounded: .rounded
            case .monospaced: .monospaced
            }
        }

        /// The UIKit design; the default one needs no descriptor change.
        var uiFont: UIFontDescriptor.SystemDesign? {
            switch self {
            case .default: nil
            case .rounded: .rounded
            case .monospaced: .monospaced
            }
        }
    }

    enum Style: String, ConfigName {
        case largeTitle, title, title2, title3, headline, body, callout, subheadline, footnote, caption, caption2

        var font: Font.TextStyle {
            switch self {
            case .largeTitle: .largeTitle
            case .title: .title
            case .title2: .title2
            case .title3: .title3
            case .headline: .headline
            case .body: .body
            case .callout: .callout
            case .subheadline: .subheadline
            case .footnote: .footnote
            case .caption: .caption
            case .caption2: .caption2
            }
        }

        var uiFont: UIFont.TextStyle {
            switch self {
            case .largeTitle: .largeTitle
            case .title: .title1
            case .title2: .title2
            case .title3: .title3
            case .headline: .headline
            case .body: .body
            case .callout: .callout
            case .subheadline: .subheadline
            case .footnote: .footnote
            case .caption: .caption1
            case .caption2: .caption2
            }
        }
    }
}
