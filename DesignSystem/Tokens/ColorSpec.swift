import SwiftUI

/// `{"light": "#RRGGBB", "dark": "#RRGGBB"}` (each color picked per theme) or `{"system": "label"}`. Checked when
/// tokens.json loads: a bad hex, an unknown system color or a color with neither is a config error, not black.
struct ColorSpec: Decodable, Sendable {
    let light: String?
    let dark: String?
    let system: SystemColor?

    /// A color the user picked (already checked hex).
    init(hex: String) {
        light = hex
        dark = hex
        system = nil
    }

    private enum CodingKeys: String, CodingKey { case light, dark, system }

    init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func hex(_ key: CodingKeys) throws -> String? {
            guard let text = try container.decodeIfPresent(String.self, forKey: key) else { return nil }
            guard UIColor(hex: text) != nil else {
                throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "\"\(text)\" is not a #RRGGBB color")
            }
            return text
        }
        light = try hex(.light)
        dark = try hex(.dark)
        system = try container.decodeIfPresent(SystemColor.self, forKey: .system)
        if (system == nil) == (light == nil) || (system != nil && dark != nil) {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "a color is either \"light\" (and \"dark\") or \"system\""))
        }
    }

    var color: Color { Color(uiColor: uiColor) }

    var uiColor: UIColor {
        if let system { return system.uiColor }
        let light = light.flatMap(UIColor.init(hex:)) ?? .label
        let dark = dark.flatMap(UIColor.init(hex:)) ?? light
        return UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }

    enum SystemColor: String, ConfigName {
        case label, secondaryLabel, tertiaryLabel
        case systemBackground, secondarySystemBackground, systemGroupedBackground, secondarySystemGroupedBackground
        case tertiarySystemFill, secondarySystemFill, quaternarySystemFill, separator, systemRed, systemBlue

        var uiColor: UIColor {
            switch self {
            case .label: .label
            case .secondaryLabel: .secondaryLabel
            case .tertiaryLabel: .tertiaryLabel
            case .systemBackground: .systemBackground
            case .secondarySystemBackground: .secondarySystemBackground
            case .systemGroupedBackground: .systemGroupedBackground
            case .secondarySystemGroupedBackground: .secondarySystemGroupedBackground
            case .tertiarySystemFill: .tertiarySystemFill
            case .secondarySystemFill: .secondarySystemFill
            case .quaternarySystemFill: .quaternarySystemFill
            case .separator: .separator
            case .systemRed: .systemRed
            case .systemBlue: .systemBlue
            }
        }
    }
}
