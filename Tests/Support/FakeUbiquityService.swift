import Foundation
@testable import SuperPooperApp

final class FakeUbiquityService: UbiquityService, @unchecked Sendable {
    private let lock = NSLock()
    private var isLocal = false
    private var evicted: Set<String> = []
    private var downloads: [String: String] = [:]
    private var conflicts: [String: [String]] = [:]
    private var requests: [String] = []
    private var checks: [String] = []

    var downloadRequests: [String] { lock.withLock { requests } }
    var conflictChecks: [String] { lock.withLock { checks } }

    func makeLocal() {
        lock.withLock { isLocal = true }
    }

    func evict(_ fileName: String) {
        lock.withLock { _ = evicted.insert(fileName) }
    }

    func willDownload(_ fileName: String, content: String) {
        lock.withLock {
            evicted.insert(fileName)
            downloads[fileName] = content
        }
    }

    /// The file gets conflicting versions with these texts.
    func conflict(_ fileName: String, versions: [String] = ["---\nstatus: done\n---\n"]) {
        lock.withLock { conflicts[fileName] = versions }
    }

    func isUbiquitous(_ folder: URL) -> Bool {
        lock.withLock { !isLocal }
    }

    func isDownloaded(_ url: URL) -> Bool {
        lock.withLock { !evicted.contains(url.lastPathComponent) }
    }

    func startDownloading(_ url: URL) throws {
        let content: String? = lock.withLock {
            requests.append(url.lastPathComponent)
            return downloads.removeValue(forKey: url.lastPathComponent)
        }
        guard let content else { return }
        try Data(content.utf8).write(to: url, options: .atomic)
        lock.withLock { _ = evicted.remove(url.lastPathComponent) }
    }

    func hasConflicts(_ url: URL) -> Bool {
        lock.withLock {
            checks.append(url.lastPathComponent)
            return conflicts[url.lastPathComponent] != nil
        }
    }

    func versions(of url: URL) throws -> [NoteVersion] {
        let others = lock.withLock { conflicts[url.lastPathComponent] ?? [] }
        let current = NoteVersion(id: "current", isCurrent: true, modified: nil, device: nil, text: try String(contentsOf: url, encoding: .utf8))
        return [current] + others.enumerated().map { NoteVersion(id: "v\($0.offset)", isCurrent: false, modified: nil, device: "Mac", text: $0.element) }
    }

    func keep(_ versionID: String, of url: URL) throws {
        let others = lock.withLock { conflicts.removeValue(forKey: url.lastPathComponent) ?? [] }
        if versionID.hasPrefix("v"), let index = Int(versionID.dropFirst()), others.indices.contains(index) {
            try Data(others[index].utf8).write(to: url, options: .atomic)
        }
    }
}
