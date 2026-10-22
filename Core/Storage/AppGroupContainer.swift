import Foundation

/// The shared folder of the app and its widgets. The group id comes from Info.plist
/// (`SPAppGroupIdentifier`, set from `Config/Shared.xcconfig`).
enum AppGroupContainer {
    static let infoKey = "SPAppGroupIdentifier"

    static func directory(bundle: Bundle = .main) -> URL {
        if let group = bundle.object(forInfoDictionaryKey: infoKey) as? String,
           let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
            return url.appendingPathComponent("SuperPooper", isDirectory: true)
        }
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return fallback.appendingPathComponent("SuperPooper", isDirectory: true)
    }
}
