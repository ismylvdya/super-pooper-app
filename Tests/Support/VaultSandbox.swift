import Foundation
@testable import SuperPooper

/// A rendered copy of the test vault in a fresh temporary folder, plus the real data-layer objects
/// (coordinated file system, scanner, repository) wired to it with fakes for iCloud and time.
struct VaultSandbox {
    let folder: URL
    let today: String

    var vault: URL { folder.appendingPathComponent("Vault", isDirectory: true) }
    var backups: URL { folder.appendingPathComponent("Backups", isDirectory: true) }
    var tasksFolder: URL { vault.appendingPathComponent(TestConfig.defaults.vault.tasksFolder, isDirectory: true) }
    var trashFolder: URL { vault.appendingPathComponent(TestConfig.defaults.vault.trashFolder, isDirectory: true) }
    /// "Now" for writes: `date_modified` gets this moment.
    var now: Date { TestCalendar.date(today, "13:25") }
    /// `now` the way TaskNotes writes `date_modified` (date-fns `yyyy-MM-dd'T'HH:mm:ss.SSSxxx`).
    var nowStamp: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TestCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSxxx"
        return formatter.string(from: now)
    }

    /// Where sandboxes go: `SUPERPOOPER_TEST_TMP` if set (keeps a host-side run inside the project's `.build`),
    /// otherwise the system temporary folder (inside the simulator when run from Xcode).
    static var baseFolder: URL {
        if let path = ProcessInfo.processInfo.environment["SUPERPOOPER_TEST_TMP"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return FileManager.default.temporaryDirectory
    }

    /// Renders `Fixtures/TestVault` for `today` (a Wednesday by default) into a new temporary folder,
    /// as a whole Obsidian vault (with `.obsidian`).
    static func make(today: String = TestCalendar.wednesday) throws -> VaultSandbox {
        let folder = baseFolder.appendingPathComponent("SuperPooperTests-\(UUID().uuidString)", isDirectory: true)
        let sandbox = VaultSandbox(folder: folder, today: today)
        let day = LocalDate(today)
        let renderer = TestVaultRenderer(year: day.year, month: day.month, day: day.day, timeZone: TestCalendar.timeZone)
        try renderer.renderVault(from: TestPaths.testVault, to: sandbox.vault)
        try FileManager.default.createDirectory(at: sandbox.vault.appendingPathComponent(".obsidian", isDirectory: true),
                                                withIntermediateDirectories: true)
        return sandbox
    }

    func url(of name: String) -> URL { tasksFolder.appendingPathComponent("\(name).md") }

    func text(of name: String) throws -> String { try String(contentsOf: url(of: name), encoding: .utf8) }

    func write(_ text: String, to name: String) throws {
        try Data(text.utf8).write(to: url(of: name), options: .atomic)
    }

    func exists(_ name: String) -> Bool { FileManager.default.fileExists(atPath: url(of: name).path) }

    func reader() -> TaskNoteReader {
        TaskNoteReader(mapping: TestConfig.mapping, taskTag: TestConfig.defaults.vault.taskTag, calendar: TestCalendar.calendar)
    }

    func scanner(ubiquity: UbiquityService = FakeUbiquityService(), downloadTimeout: TimeInterval = 0.3) -> VaultScanner {
        VaultScanner(fileSystem: CoordinatedFileSystem(), ubiquity: ubiquity, reader: reader(),
                     noteExtension: TestConfig.rules.vault.noteExtension, downloadTimeout: downloadTimeout)
    }

    func scan(ubiquity: UbiquityService = FakeUbiquityService(), downloadTimeout: TimeInterval = 0.3) async -> VaultScanResult {
        await scanner(ubiquity: ubiquity, downloadTimeout: downloadTimeout)
            .scan(root: vault, tasksFolder: TestConfig.defaults.vault.tasksFolder).result
    }

    func repository(ubiquity: UbiquityService = FakeUbiquityService(), downloadTimeout: TimeInterval = 0.3,
                    keepBackups: Int = TestConfig.rules.backups.keepCount) -> VaultTaskRepository {
        let fileSystem = CoordinatedFileSystem()
        let backupClock = TickingClock(start: now, step: 1)
        let backupService = BackupService(directory: backups, keepCount: keepBackups, fileSystem: fileSystem,
                                          clock: { backupClock.now })
        let settings = TestConfig.defaults.vault
        let rules = RulesConfig.Vault(downloadTimeoutSeconds: downloadTimeout, noteExtension: TestConfig.rules.vault.noteExtension)
        return VaultTaskRepository(location: FixedVaultLocation(url: vault), fileSystem: fileSystem, ubiquity: ubiquity,
                                   mapping: TestConfig.mapping, calendar: TestCalendar.calendar, rules: rules,
                                   backups: backupService, clock: FixedClock(now: now), vaultSettings: { settings })
    }
}

/// iCloud Drive stand-in. File names (with extension) in `evicted` report as cloud-only;
/// `startDownloading` of a file registered with `willDownload` writes its content, like a finished
/// download; `conflict` makes the next conflict check of that file report resolved versions.
/// `makeLocal` turns the vault into a plain local folder (not in iCloud Drive).
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

/// A clock that moves forward by `step` every time it is read (unique backup folder names).
final class TickingClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date
    private let step: TimeInterval

    init(start: Date, step: TimeInterval) {
        current = start
        self.step = step
    }

    var now: Date {
        lock.withLock {
            defer { current = current.addingTimeInterval(step) }
            return current
        }
    }
}
