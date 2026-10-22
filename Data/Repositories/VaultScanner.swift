import Foundation

/// Finds task notes in the tasks folder: asks iCloud for evicted files, waits for them (with a
/// timeout), resolves conflict versions and parses frontmatter. Nothing here throws on bad notes;
/// they become file problems.
struct VaultScanner: Sendable {
    let fileSystem: NoteFileSystem
    let ubiquity: UbiquityService
    let reader: TaskNoteReader
    let noteExtension: String
    let downloadTimeout: TimeInterval

    struct Output: Sendable {
        var result: VaultScanResult
        var modificationDates: [String: Date]
    }

    func scan(root: URL, tasksFolder: String) async -> Output {
        let folder = root.appendingPathComponent(tasksFolder, isDirectory: true)
        guard fileSystem.fileExists(folder), let files = try? fileSystem.listFiles(in: folder) else {
            return Output(result: VaultScanResult(tasks: [], fileProblems: [.tasksFolderMissing(tasksFolder)], conflictsResolved: []),
                          modificationDates: [:])
        }

        let isUbiquitous = ubiquity.isUbiquitous(folder)
        let notes = isUbiquitous
            ? await downloadedNotes(from: files)
            : (ready: files.filter { $0.pathExtension == noteExtension }, missing: [URL]())
        var output = Output(result: VaultScanResult(tasks: [], fileProblems: [], conflictsResolved: []), modificationDates: [:])
        for url in notes.missing {
            output.result.fileProblems.append(.notDownloaded(file: url.deletingPathExtension().lastPathComponent))
        }
        for url in notes.ready.sorted(by: { $0.path < $1.path }) {
            read(url, root: root, checkConflicts: isUbiquitous, into: &output)
        }
        return output
    }

    private func read(_ url: URL, root: URL, checkConflicts: Bool, into output: inout Output) {
        let name = url.deletingPathExtension().lastPathComponent
        let relativePath = VaultPaths.relative(url, to: root)
        if checkConflicts, (try? ubiquity.resolveConflictsKeepingLatest(url)) == true {
            output.result.conflictsResolved.append(name)
        }
        let file: NoteFile
        do {
            file = try fileSystem.read(url)
        } catch {
            output.result.fileProblems.append(.unreadable(file: name, reason: error.localizedDescription))
            return
        }
        do {
            let document = try FrontmatterDocument(text: file.text)
            guard reader.isTask(document) else { return }
            output.result.tasks.append(reader.task(from: document, name: name, relativePath: relativePath))
            output.modificationDates[relativePath] = file.modificationDate
        } catch let error as FrontmatterError {
            guard error != .noFrontmatter, file.text.contains(reader.taskTag) else { return }
            output.result.fileProblems.append(.brokenYAML(file: name, reason: FrontmatterErrorText.describe(error)))
        } catch {
            output.result.fileProblems.append(.unreadable(file: name, reason: error.localizedDescription))
        }
    }

    /// Real notes plus iCloud placeholders (`.Name.md.icloud`), downloaded within the timeout.
    private func downloadedNotes(from files: [URL]) async -> (ready: [URL], missing: [URL]) {
        var candidates: [URL] = []
        for url in files {
            if let realName = ICloudPlaceholder.realName(of: url.lastPathComponent) {
                let real = url.deletingLastPathComponent().appendingPathComponent(realName)
                if real.pathExtension == noteExtension, !files.contains(real) { candidates.append(real) }
            } else if url.pathExtension == noteExtension {
                candidates.append(url)
            }
        }
        var pending = candidates.filter { !isReady($0) }
        for url in pending { try? ubiquity.startDownloading(url) }
        let deadline = Date().addingTimeInterval(downloadTimeout)
        while !pending.isEmpty, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(250))
            pending = pending.filter { !isReady($0) }
        }
        let missing = Set(pending)
        return (candidates.filter { !missing.contains($0) }, pending)
    }

    private func isReady(_ url: URL) -> Bool {
        fileSystem.fileExists(url) && ubiquity.isDownloaded(url)
    }
}

enum VaultPaths {
    static func relative(_ url: URL, to root: URL) -> String {
        let rootPath = root.standardizedFileURL.resolvingSymlinksInPath().path
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        guard path.hasPrefix(rootPath) else { return url.lastPathComponent }
        return String(path.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

enum FrontmatterErrorText {
    static func describe(_ error: FrontmatterError) -> String {
        switch error {
        case .noFrontmatter: L10n.string("yaml.noFrontmatter")
        case .unterminated: L10n.string("yaml.unterminated")
        case .malformedLine(let line, let text): L10n.format("yaml.malformedLine", line, text)
        case .malformedValue(let key, let line, let reason): L10n.format("yaml.malformedValue", key, line, reason)
        }
    }
}
