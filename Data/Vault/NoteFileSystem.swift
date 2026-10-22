import Foundation

/// File contents with the modification date seen at read time.
struct NoteFile: Sendable {
    let text: String
    let modificationDate: Date?
}

enum NoteWriteError: Error, Equatable, Sendable {
    case notUTF8
    case nameTaken(String)
    case invalidName(String)
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
}

/// `NSFileCoordinator`-based implementation with atomic writes.
struct CoordinatedFileSystem: NoteFileSystem {
    func listFiles(in folder: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys, options: []) else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }.filter {
            (try? $0.resourceValues(forKeys: Set(keys)).isRegularFile) == true
        }
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

    func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
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

    private func coordinate(_ body: (NSFileCoordinator, NSErrorPointer) -> Void) throws {
        var error: NSError?
        body(NSFileCoordinator(filePresenter: nil), &error)
        if let error { throw error }
    }
}
