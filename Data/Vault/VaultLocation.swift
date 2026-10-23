import Foundation

enum VaultAccessError: Error, Equatable, Sendable {
    case notSelected
    case bookmarkInvalid
    case accessDenied
}

/// Where the vault is and how to get (security-scoped) access to it.
protocol VaultLocating: Sendable {
    var hasVault: Bool { get }
    var displayName: String? { get }
    /// Runs `body` with access to the vault root folder.
    func withRoot<T>(_ body: (URL) async throws -> T) async throws -> T
    func select(_ url: URL) throws
}

/// The folder picked by the user, remembered as a security-scoped bookmark in the App Group
/// and refreshed when iOS reports it as stale.
final class BookmarkVaultLocation: VaultLocating, @unchecked Sendable {
    private let store: JSONFileStore
    private let fileName = "vault-bookmark.data"
    /// A folder inside the app's own container needs no bookmark (and asking the file provider for
    /// one can hang in the simulator): its path is stored instead.
    private let pathFileName = "vault-path.txt"
    private let lock = NSLock()

    init(store: JSONFileStore) { self.store = store }

    var hasVault: Bool { store.readData(fileName) != nil || store.readData(pathFileName) != nil }

    var displayName: String? { (try? resolve())?.lastPathComponent }

    /// The container path changes with every reinstall, so the stored path is relative to it.
    private static var home: String { URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL.path + "/" }

    func select(_ url: URL) throws {
        let path = url.standardizedFileURL.path
        if path.hasPrefix(Self.home) {
            try store.writeData(Data(path.dropFirst(Self.home.count).utf8), to: pathFileName)
            store.remove(fileName)
            return
        }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        try store.writeData(data, to: fileName)
        store.remove(pathFileName)
    }

    func withRoot<T>(_ body: (URL) async throws -> T) async throws -> T {
        let url = try resolve()
        // Folders the app may read anyway (its own container) have no security scope to start.
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard accessing || FileManager.default.isReadableFile(atPath: url.path) else { throw VaultAccessError.accessDenied }
        return try await body(url)
    }

    private func resolve() throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        if let path = store.readData(pathFileName).map({ String(decoding: $0, as: UTF8.self) }) {
            return URL(fileURLWithPath: Self.home + path, isDirectory: true)
        }
        guard let data = store.readData(fileName) else { throw VaultAccessError.notSelected }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            throw VaultAccessError.bookmarkInvalid
        }
        if isStale, url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            if let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                try? store.writeData(fresh, to: fileName)
            }
        }
        return url
    }
}

/// A plain folder without bookmarks: DEBUG test vault and unit tests.
struct FixedVaultLocation: VaultLocating {
    let url: URL

    var hasVault: Bool { true }
    var displayName: String? { url.lastPathComponent }
    func select(_ url: URL) throws {}
    func withRoot<T>(_ body: (URL) async throws -> T) async throws -> T { try await body(url) }
}
