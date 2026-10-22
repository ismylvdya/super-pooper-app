import Foundation

/// The shared folder of the app and its widgets. The group id comes from Info.plist:
/// AltStore/SideStore re-sign with an adjusted group and list it under `ALTAppGroups`, so that
/// key wins; otherwise `SPAppGroupIdentifier` (set from `Config/Shared.xcconfig`).
enum AppGroupContainer {
    static let infoKey = "SPAppGroupIdentifier"
    static let altStoreKey = "ALTAppGroups"

    static func candidates(bundle: Bundle = .main) -> [String] {
        let altStore = bundle.object(forInfoDictionaryKey: altStoreKey) as? [String] ?? []
        let own = (bundle.object(forInfoDictionaryKey: infoKey) as? String).map { [$0] } ?? []
        return altStore + own
    }

    static func directory(bundle: Bundle = .main) -> URL {
        for group in candidates(bundle: bundle) {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
                return url.appendingPathComponent("SuperPooper", isDirectory: true)
            }
        }
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return fallback.appendingPathComponent("SuperPooper", isDirectory: true)
    }
}
