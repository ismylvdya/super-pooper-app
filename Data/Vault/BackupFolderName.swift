import Foundation

/// The name of a backup folder: the UTC moment it was made and why, `20261021T003000.000Z-delete`. Folders of older
/// versions are named by the phone's clock then, `20261021-023000-000-delete`; they are read on its clock now, which is
/// right unless the phone changed its zone since. Rotation goes by these moments: the names of the two kinds do not
/// sort among each other.
enum BackupFolderName {
    private static let utcFormat = "yyyyMMdd'T'HHmmss.SSS'Z'"
    private static let legacyFormat = "yyyyMMdd-HHmmss-SSS"

    static func make(at moment: Date, reason: String) -> String {
        "\(formatter(utcFormat, in: utc).string(from: moment))-\(reason)"
    }

    /// When the backup was made; nil for a folder that is not a backup's.
    static func moment(of name: String, legacyZone: TimeZone) -> Date? {
        if let moment = formatter(utcFormat, in: utc).date(from: String(name.prefix(20))) { return moment }
        return formatter(legacyFormat, in: legacyZone).date(from: String(name.prefix(19)))
    }

    private static let utc = TimeZone(identifier: "UTC") ?? .gmt

    private static func formatter(_ format: String, in zone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = format
        return formatter
    }
}
