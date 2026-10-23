import Foundation

/// The Lock Screen clock line: the user's prefix and the time in the chosen zone ("🇷🇺 14:05").
/// The prefix may spell invisible characters as `\u{2800}` or `U+2800`, since they are hard to type.
enum ClockLine {
    static func text(prefix: String, date: Date, timeZone: TimeZone) -> String {
        decode(prefix) + time(date, timeZone: timeZone)
    }

    static func time(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    static func decode(_ prefix: String) -> String {
        var result = ""
        var rest = Substring(prefix)
        while !rest.isEmpty {
            if let (scalar, length) = escapedScalar(rest) {
                result.unicodeScalars.append(scalar)
                rest = rest.dropFirst(length)
            } else {
                result.append(rest.removeFirst())
            }
        }
        return result
    }

    /// `\u{XXXX}` or `U+XXXX` at the start of `text`: the scalar and how many characters it took.
    private static func escapedScalar(_ text: Substring) -> (Unicode.Scalar, Int)? {
        if text.hasPrefix("\\u{"), let close = text.firstIndex(of: "}") {
            let hex = text[text.index(text.startIndex, offsetBy: 3)..<close]
            guard let value = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(value) else { return nil }
            return (scalar, text.distance(from: text.startIndex, to: close) + 1)
        }
        if text.hasPrefix("U+") {
            let hex = text.dropFirst(2).prefix { $0.isHexDigit }.prefix(6)
            guard hex.count >= 4, let value = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(value) else { return nil }
            return (scalar, 2 + hex.count)
        }
        return nil
    }
}
