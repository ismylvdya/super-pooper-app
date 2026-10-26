import Foundation

/// File contents with the modification date seen at read time.
struct NoteFile: Sendable {
    let text: String
    let modificationDate: Date?
}

enum NoteWriteError: Error, Equatable, Sendable {
    case notUTF8
}

/// File operations on notes, coordinated with other writers (iCloud, Obsidian).
protocol NoteFileSystem: Sendable {
    func listFiles(in folder: URL) throws -> [URL]
    func read(_ url: URL) throws -> NoteFile
    func modificationDate(of url: URL) -> Date?
    func write(_ text: String, to url: URL) throws
    func move(_ url: URL, to destination: URL) throws
    func copy(_ url: URL, to destination: URL) throws
    func fileExists(_ url: URL) -> Bool
    /// Deletes a file for good (only the trash screen does this, after the user confirms).
    func remove(_ url: URL) throws
}

extension NoteFileSystem {
    /// What was written is read back before the change counts as made (and before the app says it is).
    func isWritten(_ text: String, at url: URL) -> Bool {
        (try? read(url).text) == text
    }

    /// A move counts once the note is at its new place and gone from the old one (a rename that only changes
    /// letter case keeps the same file).
    func isMoved(_ source: URL, to target: URL) -> Bool {
        let samePlace = source.standardizedFileURL.path.lowercased() == target.standardizedFileURL.path.lowercased()
        return fileExists(target) && (samePlace || !fileExists(source))
    }
}

/// `NSFileCoordinator`-based implementation with atomic writes.
struct CoordinatedFileSystem: NoteFileSystem {
    /// Only the cheap `isRegularFile` key: iCloud attributes are slow to fetch and are asked
    /// for only when the folder is in iCloud Drive. Hidden folders inside (the trash, `.obsidian`) are skipped;
    /// hidden files stay, since iCloud keeps not-yet-downloaded notes as `.Name.md.icloud`.
    func listFiles(in folder: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys, options: []) else {
            return []
        }
        var files: [URL] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true, url.lastPathComponent.hasPrefix(".") {
                enumerator.skipDescendants()
            } else if values?.isRegularFile == true {
                files.append(url)
            }
        }
        return files
    }

    func read(_ url: URL) throws -> NoteFile {
        var result: Result<NoteFile, Error> = .failure(CocoaError(.fileReadUnknown))
        try coordinate { coordinator, errorPointer in
            coordinator.coordinate(readingItemAt: url, options: [], error: errorPointer) { readURL in
                result = Result {
                    let data = try Data(contentsOf: readURL)
                    guard let text = String(data: data, encoding: .utf8) else { throw NoteWriteError.notUTF8 }
                    return NoteFile(text: text, modificationDate: modificationDate(of: readURL))
                }
            }
        }
        return try result.get()
    }

    /// Always read from disk: a URL caches resource values, and a stale date would make the app's
    /// own previous write look like an edit made elsewhere.
    func modificationDate(of url: URL) -> Date? {
        var url = url
        url.removeCachedResourceValue(forKey: .contentModificationDateKey)
        return try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    func write(_ text: String, to url: URL) throws {
        var result: Result<Void, Error> = .success(())
        try coordinate { coordinator, errorPointer in
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: errorPointer) { writeURL in
                result = Result { try Data(text.utf8).write(to: writeURL, options: .atomic) }
            }
        }
        try result.get()
    }

    func move(_ url: URL, to destination: URL) throws {
        var result: Result<Void, Error> = .success(())
        try coordinate { coordinator, errorPointer in
            coordinator.coordinate(writingItemAt: url, options: .forMoving, writingItemAt: destination,
                                   options: .forReplacing, error: errorPointer) { source, target in
                result = Result {
                    try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try FileManager.default.moveItem(at: source, to: target)
                }
            }
        }
        try result.get()
    }

    func copy(_ url: URL, to destination: URL) throws {
        var result: Result<Void, Error> = .success(())
        try coordinate { coordinator, errorPointer in
            coordinator.coordinate(readingItemAt: url, options: [], error: errorPointer) { source in
                result = Result {
                    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: source, to: destination)
                }
            }
        }
        try result.get()
    }

    func fileExists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    func remove(_ url: URL) throws {
        var result: Result<Void, Error> = .success(())
        try coordinate { coordinator, errorPointer in
            coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: errorPointer) { target in
                result = Result { try FileManager.default.removeItem(at: target) }
            }
        }
        try result.get()
    }

    private func coordinate(_ body: (NSFileCoordinator, NSErrorPointer) -> Void) throws {
        var error: NSError?
        body(NSFileCoordinator(filePresenter: nil), &error)
        if let error { throw error }
    }
}
