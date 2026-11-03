import Foundation

/// The trash (a section of the file for tasks, a folder beside the habits for habits), the day's look, links into
/// Obsidian, backups and what the chosen folder is.
extension TaskFileStore: TaskTrash, DayMirroring, TaskImporting, ExternalLinking, TaskBackups, FolderInspecting {
    private static let taskPrefix = "task:"
    private static let habitPrefix = "habit:"

    func delete(_ task: TaskItem) async throws -> TrashedNote? {
        try await location.withRoot { root in
            var snapshot = try await read(root: root)
            let id = task.id.value
            if snapshot.habits[id] != nil {
                let source = habitsFolder(root: root).appendingPathComponent(id + ".json")
                try fileSystem.move(source, to: habitsTrash(root: root).appendingPathComponent(id + ".json"))
                while snapshot.document.remove(where: { $0.id == id && $0.completed == nil }) != nil {}
                try write(snapshot.document, root: root)
                return TrashedNote(id: Self.habitPrefix + id, name: task.name, trashedAt: fileSystem.modificationDate(of: source))
            }
            guard let taken = snapshot.document.remove(where: { $0.id == id }) else { throw TaskStoreError.fileMissing(task.name) }
            // A subtask that went along with its parent is in the trash already.
            guard taken.section != .trash else { return nil }
            var entry = taken.entry
            entry.deleted = today()
            entry.parent = nil
            snapshot.document.insert(entry, into: .trash, atTop: true)
            try write(snapshot.document, root: root)
            return TrashedNote(id: Self.taskPrefix + id, name: entry.name, trashedAt: nil)
        }
    }

    func notes() async throws -> [TrashedNote] {
        try await location.withRoot { root in
            let snapshot = try await read(root: root)
            let calendar = Calendar.current
            var notes: [TrashedNote] = []
            for section in snapshot.document.sections where section.kind == .trash {
                for entry in section.groups.flatMap(\.entries) {
                    guard let id = entry.id else { continue }
                    notes.append(TrashedNote(id: Self.taskPrefix + id, name: entry.name, trashedAt: entry.deleted?.startDate(in: calendar)))
                }
            }
            let folder = habitsTrash(root: root)
            if fileSystem.fileExists(folder) {
                for url in try fileSystem.contents(of: folder) where url.pathExtension == "json" {
                    guard let data = try fileSystem.read(url).text.data(using: .utf8),
                          let file = try? JSONDecoder().decode(HabitFile.self, from: data) else { continue }
                    notes.append(TrashedNote(id: Self.habitPrefix + file.id, name: file.name, trashedAt: fileSystem.modificationDate(of: url)))
                }
            }
            return notes.sorted { ($0.trashedAt ?? .distantPast) > ($1.trashedAt ?? .distantPast) }
        }
    }

    func text(of note: TrashedNote) async throws -> String {
        try await location.withRoot { root in
            if note.id.hasPrefix(Self.habitPrefix) {
                let url = habitsTrash(root: root).appendingPathComponent(String(note.id.dropFirst(Self.habitPrefix.count)) + ".json")
                guard let data = try fileSystem.read(url).text.data(using: .utf8) else { return "" }
                return try JSONDecoder().decode(HabitFile.self, from: data).note
            }
            let snapshot = try await read(root: root)
            return snapshot.document.entry(id: String(note.id.dropFirst(Self.taskPrefix.count)))?.note.joined(separator: "\n") ?? ""
        }
    }

    func restore(_ note: TrashedNote) async throws -> String {
        try await location.withRoot { root in
            var snapshot = try await read(root: root)
            if note.id.hasPrefix(Self.habitPrefix) {
                let id = String(note.id.dropFirst(Self.habitPrefix.count))
                let url = habitsTrash(root: root).appendingPathComponent(id + ".json")
                guard let data = try fileSystem.read(url).text.data(using: .utf8) else { throw TaskStoreError.fileMissing(note.name) }
                var file = try JSONDecoder().decode(HabitFile.self, from: data)
                file.name = UniqueName.free(file.name) { snapshot.isTaken($0) }
                try write(file, root: root)
                try fileSystem.remove(url)
                return file.name
            }
            let id = String(note.id.dropFirst(Self.taskPrefix.count))
            guard var taken = snapshot.document.remove(where: { $0.id == id })?.entry else { throw TaskStoreError.fileMissing(note.name) }
            snapshot.indexNames()
            taken.name = UniqueName.free(taken.name) { snapshot.isTaken($0) }
            taken.deleted = nil
            snapshot.document.insert(taken, into: .now)
            try write(snapshot.document, root: root)
            return taken.name
        }
    }

    func deletePermanently(_ note: TrashedNote) async throws {
        try await location.withRoot { root in
            if note.id.hasPrefix(Self.habitPrefix) {
                try fileSystem.remove(habitsTrash(root: root).appendingPathComponent(String(note.id.dropFirst(Self.habitPrefix.count)) + ".json"))
                return
            }
            var snapshot = try await read(root: root)
            let id = String(note.id.dropFirst(Self.taskPrefix.count))
            _ = snapshot.document.remove(where: { $0.id == id })
            try write(snapshot.document, root: root)
        }
    }

    // MARK: - The day's look

    /// Now as the day stands: first what has no section (timed, or not in the plan), then the pool's sections under their
    /// titles, a habit's line for each habit shown; what was kept out of today goes to Soon. Sections with nothing left
    /// are gone. Nothing is read back from it: the marks ticked on a habit's line are, by `normalize`.
    func mirror(_ day: DayMirror) async {
        try? await location.withRoot { root in
            var snapshot = try await read(root: root)
            // Today's lines of habits are made anew.
            let habitIDs = Set(snapshot.habits.keys)
            let isToday = { (section: TaskDocument.Section) in section.kind == .now || section.kind == .soon }
            for index in snapshot.document.sections.indices where isToday(snapshot.document.sections[index]) {
                for group in snapshot.document.sections[index].groups.indices {
                    snapshot.document.sections[index].groups[group].entries.removeAll { $0.id.map(habitIDs.contains) ?? false }
                }
            }
            let line = { (name: String) -> TaskEntry? in
                guard let id = snapshot.id(ofName: name), let file = snapshot.habits[id] else { return nil }
                var entry = TaskEntry(name: file.name)
                entry.id = id
                entry.routine = file.options.timeOfDay?.rawValue
                entry.time = day.timed[name]
                return entry
            }
            var document = snapshot.document
            let take = { (name: String) -> TaskEntry? in
                document.remove(where: { $0.name.isSameNoteName(as: name) && $0.completed == nil })?.entry
            }
            var groups: [TaskDocument.Group] = []
            for section in day.sections {
                let entries = section.names.compactMap { name in line(name) ?? take(name) }
                if !entries.isEmpty { groups.append(TaskDocument.Group(title: section.title, entries: entries)) }
            }
            let timedHabits = day.timed.keys.sorted().compactMap(line)
            let kept = day.keptOut.compactMap(take)
            guard let now = document.sections.firstIndex(where: { $0.kind == .now }) else { return }
            let loose = document.sections[now].groups.flatMap(\.entries)
            document.sections[now].groups = [TaskDocument.Group(title: nil, entries: loose + timedHabits)] + groups
            for entry in kept { document.insert(entry, into: .soon) }
            try write(document, root: root)
        }
    }

    // MARK: - Beyond the file

    func backup(_ tasks: [TaskItem], reason: String) async throws {
        try await location.withRoot { root in
            let url = fileURL(root: root)
            guard fileSystem.fileExists(url) else { return }
            _ = try backups.backup([url], reason: reason)
        }
    }

    /// `obsidian://open?vault=…&file=…`: the tasks file, where the item's line is.
    func externalURL(for task: TaskItem) async -> URL? {
        let settings = vaultSettings()
        return try? await location.withRoot { root in
            ObsidianLink.url(relativePath: VaultPaths.relative(fileURL(root: root), to: root), root: root, folder: chosenFolder(root: root),
                             vaultName: settings.obsidianVault, pathPrefix: settings.obsidianPathPrefix, obsidian: obsidian)
        }
    }

    func chosenFolder() async -> ChosenFolder {
        (try? await location.withRoot { root in chosenFolder(root: root) }) ?? ChosenFolder()
    }

    private func chosenFolder(root: URL) -> ChosenFolder {
        ChosenFolder(isWholeVault: VaultPaths.isWholeVault(root, configFolder: obsidian.configFolder, exists: fileSystem.fileExists),
                     obsidianPlace: VaultPaths.obsidianPlace(of: root, vaultsFolder: obsidian.vaultsFolder))
    }
}
