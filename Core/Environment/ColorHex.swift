import UIKit

/// Colors as hex text: the settings and the calendars store `#RRGGBB`.
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
