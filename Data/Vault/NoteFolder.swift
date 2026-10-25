import Foundation

/// Names of the notes in a folder, compared like Obsidian links (any case, any Unicode form); a note that iCloud
/// has not downloaded yet (`.Name.md.icloud`) takes its name too.
struct NoteFolder {
    let files: [URL]

    init(_ folder: URL, fileSystem: NoteFileSystem) {
        files = (try? fileSystem.listFiles(in: folder)) ?? []
    }

    /// `except`: the note's own file (renaming it to another spelling of the same name).
    func isTaken(_ name: String, except: URL? = nil) -> Bool {
        let excluded = except.map(Self.comparablePath)
        return files.contains { file in
            guard excluded.map({ !Self.comparablePath(file).isSameNoteName(as: $0) }) ?? true else { return false }
            let fileName = ICloudPlaceholder.realName(of: file.lastPathComponent) ?? file.lastPathComponent
            return (fileName as NSString).deletingPathExtension.isSameNoteName(as: name)
        }
    }

    private static func comparablePath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
