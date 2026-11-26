import Foundation

/// The trash (a section of the file for tasks, a folder beside the habits for habits), the day's look, links into
/// Obsidian, backups and what the chosen folder is.
extension TaskFileStore: TaskTrash, DayMirroring, ExternalLinking, TaskBackups, FolderInspecting {
    private static let taskPrefix = "task:"
    private static let habitPrefix = "habit:"

    func delete(_ task: TaskItem) async throws -> TrashedNote? {
        try await location.withRoot { root in
            var snapshot = try await read(root: root)
            let id = task.id.value
            if snapshot.habits[id] != nil {
                let source = habitsFolder(root: root).appendingPathComponent(id + ".json")
                try fileSystem.move(source, to: habitsTrash(root: root).appendingPathComponent(id + ".json"))
                while removeHabitLine(id, from: &snapshot.document) != nil {}
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
            TaskLineIDs.assign(to: &snapshot.document, habits: Set(snapshot.habits.keys))
            return TrashedNote(id: Self.taskPrefix + (snapshot.document.newest(named: entry.name, in: .trash) ?? id), name: entry.name, trashedAt: nil)
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
                let minutes = rules.estimateMinutes(file.timeEstimate)
                if let previous = file.timeEstimate, previous != minutes {
                    _ = try? backups.backup([url], reason: "habit-estimates")
                }
                file.timeEstimate = minutes
                try write(file, root: root)
                try fileSystem.remove(url)
                return file.name
            }
            let id = String(note.id.dropFirst(Self.taskPrefix.count))
            guard var taken = snapshot.document.remove(where: { $0.id == id })?.entry else { throw TaskStoreError.fileMissing(note.name) }
            snapshot.indexNames()
            taken.name = UniqueName.free(taken.name) { snapshot.isTaken($0) }
            taken.deleted = nil
            taken.id = TaskLineIDs.open(taken.name)
            snapshot.document.insert(taken, into: .soon)
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

    /// The habits' lines as the day stands, at the top of Next actions: a line on today for each habit shown today, in
    /// the pool's order and then the timeline's, at the time it stands at today; the other habits (closed today, kept
    /// out of today, or not theirs today) on their next day (`waitingHabitLines`). A task's line says itself where it
    /// stands, so it is left as it is. A look changed elsewhere and not taken in yet is not written over: the next sync
    /// brings it in. Says where each habit's line stands now; nil when nothing was written.
    func mirror(_ day: DayMirror) async -> [TaskID: TaskDue]? {
        try? await location.withRoot { root -> [TaskID: TaskDue]? in
            var snapshot = try await read(root: root)
            guard changedLook(in: snapshot) == nil else { return nil }
            let dayOfFile = today()
            let wasOverdue = Set(snapshot.habits.keys.filter { id in
                let line = snapshot.document.openLine(of: id)
                return line?.isOverdue == true && line?.date == dayOfFile
            })
            let line = { (name: String) -> TaskEntry? in
                guard let id = snapshot.id(ofName: name), let file = snapshot.habits[id] else { return nil }
                let item = self.habit(of: file, snapshot: snapshot)
                // A closed day's habit has its next line; its copy is in Done.
                if self.isClosed(item, on: dayOfFile) { return nil }
                return self.habitLine(file, item: item, date: dayOfFile, time: day.timed[name], isOverdue: wasOverdue.contains(id))
            }
            var document = snapshot.document
            guard let list = document.sections.firstIndex(where: { $0.kind == .soon }) else { return nil }

            let pooled = day.sections.flatMap(\.names)
            let timed = day.timed.keys.sorted().filter { !pooled.containsNoteName($0) }
            var seen: Set<String> = []
            let todays = (pooled + timed).compactMap(line).filter { seen.insert($0.id ?? $0.name).inserted }
            let placed = Set(todays.compactMap(\.id))
            // The habits' lines are made anew in their places, their subtasks staying under them.
            let habitLines = todays + waitingHabitLines(except: placed, skipped: day.skipped, snapshot: snapshot, today: dayOfFile)
            placeHabitLines(habitLines, in: &document, habits: Set(snapshot.habits.keys))
            try write(document, root: root)
            snapshot.document = document
            lookMemory.save(look(of: snapshot))
            var lines: [TaskID: TaskDue] = [:]
            for id in snapshot.habits.keys {
                if let line = document.openLine(of: id), let date = line.date { lines[TaskID(id)] = TaskDue(day: date, time: line.time) }
            }
            return lines
        }
    }

    func changedLook() async -> DayLook? {
        (try? await location.withRoot { root in changedLook(in: try await read(root: root)) }) ?? nil
    }

    func currentLook() async -> DayLook? {
        try? await location.withRoot { root in
            let snapshot = try await read(root: root)
            return snapshot.document.prelude.contains(dayMarker) ? look(of: snapshot) : nil
        }
    }

    func accept(_ look: DayLook) async {
        lookMemory.save(look)
    }

    func lastLook() async -> DayLook? {
        lookMemory.load()
    }

    /// The file's look when it is about today and differs from what this device last saw. A file about another day has
    /// no news: the day has turned, and its sections start anew.
    private func changedLook(in snapshot: Snapshot) -> DayLook? {
        guard snapshot.document.prelude.contains(dayMarker) else { return nil }
        let look = look(of: snapshot)
        return lookMemory.load().map { look.differs(from: $0) } ?? true ? look : nil
    }

    /// The habits' lines of today in Next actions (their times), and the habits taken out of today.
    private func look(of snapshot: Snapshot) -> DayLook {
        let habits = snapshot.habits
        let day = today()
        var look = DayLook()
        var times: [String: LocalTime] = [:]
        for section in snapshot.document.sections where section.kind == .soon {
            for entry in section.groups.flatMap(\.entries) {
                guard let id = entry.id, let file = habits[id], let date = entry.date else { continue }
                if date == day {
                    if let time = entry.time { times[entry.name] = time } else { look.untimed.append(entry.name) }
                } else if date > day, let (item, schedule) = schedule(of: file, snapshot: snapshot), schedule.occurs(on: day),
                          !isClosed(item, on: day) {
                    // A habit whose day is today, waiting for a later one: it was taken out of today.
                    look.skipped.append(entry.name)
                }
            }
        }
        look.times = times
        return look
    }

    var dayMarker: String { format.dayMarkerPrefix + today().isoString + format.dayMarkerSuffix }

    func setDayMarker(in document: inout TaskDocument) {
        document.prelude.removeAll { $0.hasPrefix(format.dayMarkerPrefix) && $0.hasSuffix(format.dayMarkerSuffix) }
        document.prelude.insert(dayMarker, at: 0)
    }

    // MARK: - Beyond the file

    func backup(_ tasks: [TaskItem], reason: String) async throws {
        try await location.withRoot { root in
            let urls = [fileURL(root: root), doneURL(root: root)].filter(fileSystem.fileExists)
            guard !urls.isEmpty else { return }
            _ = try backups.backup(urls, reason: reason)
        }
    }

    /// `obsidian://superpooper-line?vault=…&file=…&line=…&name=…`: the tasks file on the item's line (a habit's open one), by the
    /// app's plugin for Obsidian.
    func externalURL(for task: TaskItem) async -> URL? {
        let settings = vaultSettings()
        return try? await location.withRoot { root in
            let document = try await read(root: root).document
            return ObsidianLink.url(relativePath: VaultPaths.relative(fileURL(root: root), to: root), root: root, folder: chosenFolder(root: root),
                                    vaultName: settings.obsidianVault, pathPrefix: settings.obsidianPathPrefix, obsidian: obsidian,
                                    line: document.openLine(of: task.id.value, format: format))
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
