import Foundation

/// A time zone as its offset from UTC ("UTC+3", "UTC−7", "UTC+5:30"): short, and the same everywhere,
/// unlike abbreviations (the system has "CET" for Berlin but only "GMT+3" for Moscow).
enum TimeZoneName {
    static func offset(_ zone: TimeZone, at date: Date) -> String {
        let seconds = zone.secondsFromGMT(for: date)
        guard seconds != 0 else { return L10n.string("clock.offset.zero") }
        let hours = abs(seconds) / 3600
        let minutes = abs(seconds) % 3600 / 60
        let amount = minutes == 0 ? String(hours) : String(format: "%d:%02d", hours, minutes)
        return L10n.format(seconds > 0 ? "clock.offset.east" : "clock.offset.west", amount)
    }

    /// The city of a zone identifier ("Europe/Moscow" → "Moscow", "America/Port_of_Spain" → "Port of Spain").
    static func city(_ identifier: String) -> String {
        String(identifier.split(separator: "/").last ?? Substring(identifier)).replacingOccurrences(of: "_", with: " ")
    }
}
