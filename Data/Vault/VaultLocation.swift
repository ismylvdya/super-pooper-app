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
    private let lock = NSLock()

    init(store: JSONFileStore) { self.store = store }

    var hasVault: Bool { store.readData(fileName) != nil }

    var displayName: String? { (try? resolve())?.lastPathComponent }

    func select(_ url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        try store.writeData(data, to: fileName)
    }

    func withRoot<T>(_ body: (URL) async throws -> T) async throws -> T {
        let url = try resolve()
        guard url.startAccessingSecurityScopedResource() else { throw VaultAccessError.accessDenied }
        defer { url.stopAccessingSecurityScopedResource() }
        return try await body(url)
    }

    private func resolve() throws -> URL {
        lock.lock()
        defer { lock.unlock() }
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
