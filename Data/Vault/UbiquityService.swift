import Foundation

/// iCloud Drive specifics behind a protocol, so tests can fake evicted files and conflicts.
protocol UbiquityService: Sendable {
    /// Whether the folder lives in iCloud Drive at all; local folders skip the (slow) iCloud checks.
    func isUbiquitous(_ folder: URL) -> Bool
    /// `false` while the file is only a cloud placeholder.
    func isDownloaded(_ url: URL) -> Bool
    func startDownloading(_ url: URL) throws
    /// Whether iCloud holds conflicting versions of the file. The app never picks one by itself.
    func hasConflicts(_ url: URL) -> Bool
    /// The file as it is now plus every conflicting version, for the user to compare.
    func versions(of url: URL) throws -> [NoteVersion]
    /// Makes `versionID` the file and drops the other versions.
    func keep(_ versionID: String, of url: URL) throws
}

/// One version of a note in an iCloud conflict.
struct NoteVersion: Identifiable, Hashable, Sendable {
    let id: String
    /// The file as this device has it right now.
    let isCurrent: Bool
    let modified: Date?
    /// The device that saved it, when iCloud knows.
    let device: String?
    let text: String
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
    func hasConflicts(_ url: URL) -> Bool {
        guard !isInAppContainer(url) else { return false }
        let keys: Set<URLResourceKey> = [.isUbiquitousItemKey, .ubiquitousItemHasUnresolvedConflictsKey]
        guard let values = try? url.resourceValues(forKeys: keys), values.isUbiquitousItem == true else { return false }
        return values.ubiquitousItemHasUnresolvedConflicts == true
    }

    func versions(of url: URL) throws -> [NoteVersion] {
        var result: [NoteVersion] = []
        if let current = NSFileVersion.currentVersionOfItem(at: url) {
            result.append(NoteVersion(id: Self.currentID, isCurrent: true, modified: current.modificationDate,
                                      device: current.localizedNameOfSavingComputer, text: try String(contentsOf: url, encoding: .utf8)))
        }
        for version in NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? [] {
            result.append(NoteVersion(id: version.url.path, isCurrent: false, modified: version.modificationDate,
                                      device: version.localizedNameOfSavingComputer,
                                      text: (try? String(contentsOf: version.url, encoding: .utf8)) ?? ""))
        }
        return result
    }

    func keep(_ versionID: String, of url: URL) throws {
        let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []
        if versionID != Self.currentID, let chosen = conflicts.first(where: { $0.url.path == versionID }) {
            try chosen.replaceItem(at: url, options: [])
        }
        for version in conflicts { version.isResolved = true }
        try NSFileVersion.removeOtherVersionsOfItem(at: url)
    }

    private static let currentID = "current"
}

/// Placeholder files of evicted items look like `.Name.md.icloud`.
enum ICloudPlaceholder {
    static func realName(of fileName: String) -> String? {
        guard fileName.hasPrefix("."), fileName.hasSuffix(".icloud") else { return nil }
        return String(fileName.dropFirst().dropLast(".icloud".count))
    }
}
