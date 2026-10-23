import Foundation

/// iCloud Drive specifics behind a protocol, so tests can fake evicted files and conflicts.
protocol UbiquityService: Sendable {
    /// Whether the folder lives in iCloud Drive at all; local folders skip the (slow) iCloud checks.
    func isUbiquitous(_ folder: URL) -> Bool
    /// `false` while the file is only a cloud placeholder.
    func isDownloaded(_ url: URL) -> Bool
    func startDownloading(_ url: URL) throws
    /// iCloud conflict versions; keeps the most recent one as the file. Returns `true` if
    /// there were conflicts.
    func resolveConflictsKeepingLatest(_ url: URL) throws -> Bool
}

extension UbiquityService {
    func isUbiquitous(_ folder: URL) -> Bool { true }
}

/// Real iCloud Drive behaviour.
struct ICloudUbiquityService: UbiquityService {
    /// The app's own container is never iCloud; asking the file provider about it can block (simulator).
    private func isInAppContainer(_ url: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL.path + "/")
    }

    func isUbiquitous(_ folder: URL) -> Bool {
        guard !isInAppContainer(folder) else { return false }
        return (try? folder.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true
    }

    func isDownloaded(_ url: URL) -> Bool {
        guard !isInAppContainer(url) else { return true }
        var url = url
        url.removeCachedResourceValue(forKey: .ubiquitousItemDownloadingStatusKey)
        guard let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]),
              values.isUbiquitousItem == true else { return true }
        return values.ubiquitousItemDownloadingStatus == .current || values.ubiquitousItemDownloadingStatus == .downloaded
    }

    func startDownloading(_ url: URL) throws {
        try FileManager.default.startDownloadingUbiquitousItem(at: url)
    }

    /// Asking `NSFileVersion` is slow, so the cheap resource flag is checked first.
    func resolveConflictsKeepingLatest(_ url: URL) throws -> Bool {
        guard !isInAppContainer(url) else { return false }
        let keys: Set<URLResourceKey> = [.isUbiquitousItemKey, .ubiquitousItemHasUnresolvedConflictsKey]
        guard let values = try? url.resourceValues(forKeys: keys), values.isUbiquitousItem == true,
              values.ubiquitousItemHasUnresolvedConflicts == true,
              let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url), !conflicts.isEmpty else { return false }
        let current = NSFileVersion.currentVersionOfItem(at: url)
        let newest = conflicts.max { ($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast) }
        if let newest, (newest.modificationDate ?? .distantPast) > (current?.modificationDate ?? .distantPast) {
            try newest.replaceItem(at: url, options: [])
        }
        for version in conflicts { version.isResolved = true }
        try NSFileVersion.removeOtherVersionsOfItem(at: url)
        return true
    }
}

/// Placeholder files of evicted items look like `.Name.md.icloud`.
enum ICloudPlaceholder {
    static func realName(of fileName: String) -> String? {
        guard fileName.hasPrefix("."), fileName.hasSuffix(".icloud") else { return nil }
        return String(fileName.dropFirst().dropLast(".icloud".count))
    }
}
