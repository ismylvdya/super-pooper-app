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
    /// are gone. A look changed elsewhere and not taken in yet is not written over: the next sync brings it in.
    func mirror(_ day: DayMirror) async {
        try? await location.withRoot { root in
            var snapshot = try await read(root: root)
            guard changedLook(in: snapshot) == nil else { return }
            let dayOfFile = today()
            let wasOverdue = Set(snapshot.habits.keys.filter { id in
                let line = snapshot.document.openLine(of: id)
                return line?.isOverdue == true && line?.date == dayOfFile
            })
            let line = { (name: String) -> TaskEntry? in
                guard let id = snapshot.id(ofName: name), let file = snapshot.habits[id] else { return nil }
                let item = self.habit(of: file, snapshot: snapshot)
                // A closed day's habit has its next line in Soon; its copy is in Done.
                if self.isClosed(item, on: dayOfFile) { return nil }
                return self.habitLine(file, item: item, date: dayOfFile, time: day.timed[name], isOverdue: wasOverdue.contains(id))
            }
            // Today's lines of habits are made anew.
            let habitIDs = Set(snapshot.habits.keys)
            let isToday = { (section: TaskDocument.Section) in section.kind == .now || section.kind == .soon }
            var document = snapshot.document
            for index in document.sections.indices where isToday(document.sections[index]) {
                for group in document.sections[index].groups.indices {
                    document.sections[index].groups[group].entries.removeAll { $0.id.map(habitIDs.contains) ?? false }
                }
            }
            let take = { (name: String) -> TaskEntry? in
                document.remove(where: { $0.name.isSameNoteName(as: name) && $0.completed == nil && $0.deleted == nil })?.entry
            }
            var groups: [TaskDocument.Group] = []
            for section in day.sections {
                let entries = section.names.compactMap { name in line(name) ?? take(name) }
                if !entries.isEmpty { groups.append(TaskDocument.Group(title: section.title, entries: entries)) }
            }
            let inSections = Set(day.sections.flatMap(\.names).map(\.noteName))
            let timedHabits = day.timed.keys.sorted().filter { !inSections.contains($0.noteName) }.compactMap(line)
            let kept = day.keptOut.compactMap(take)
            guard let now = document.sections.firstIndex(where: { $0.kind == .now }) else { return }
            let loose = document.sections[now].groups.flatMap(\.entries)
            document.sections[now].groups = [TaskDocument.Group(title: nil, entries: loose + timedHabits)] + groups
            for entry in kept { document.insert(entry, into: .soon) }
            let placed = Set((groups.flatMap(\.entries) + timedHabits).compactMap(\.id))
            for entry in waitingHabitLines(except: placed, snapshot: snapshot, today: dayOfFile) { document.insert(entry, into: .soon) }
            setDayMarker(in: &document)
            try write(document, root: root)
            lookMemory.save(look(of: document, habits: snapshot.habits))
        }
    }

    func changedLook() async -> DayLook? {
        (try? await location.withRoot { root in changedLook(in: try await read(root: root)) }) ?? nil
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
        let look = look(of: snapshot.document, habits: snapshot.habits)
        return lookMemory.load().map { look.differs(from: $0) } ?? true ? look : nil
    }

    /// Now's titled groups, and the undated open tasks of Soon: what was kept out of today.
    private func look(of document: TaskDocument, habits: [String: HabitFile]) -> DayLook {
        var look = DayLook()
        for section in document.sections {
            if section.kind == .now {
                look.sections = section.groups.compactMap { group in
                    group.title.map { DayLook.Section(title: $0, names: group.entries.map(\.name)) }
                }
                var times: [String: LocalTime] = [:]
                for entry in section.groups.flatMap(\.entries) where entry.id.map({ habits[$0] != nil }) ?? false {
                    if let time = entry.time { times[entry.name] = time }
                }
                look.times = times
            } else if section.kind == .soon {
                look.keptOut = section.groups.flatMap(\.entries)
                    .filter { $0.date == nil && $0.box != .done && !($0.id.map { habits[$0] != nil } ?? false) }
                    .map(\.name)
            }
        }
        return look
    }

    private var dayMarker: String { format.dayMarkerPrefix + today().isoString + format.dayMarkerSuffix }

    private func setDayMarker(in document: inout TaskDocument) {
        document.prelude.removeAll { $0.hasPrefix(format.dayMarkerPrefix) && $0.hasSuffix(format.dayMarkerSuffix) }
        document.prelude.insert(dayMarker, at: 0)
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
            var snapshot = try await read(root: root)
            // The link points at a block id on the item's line (a habit's open one); the last line opened gives it up.
            markOpenTarget(task.id.value, in: &snapshot.document)
            try write(snapshot.document, root: root)
            return ObsidianLink.url(relativePath: VaultPaths.relative(fileURL(root: root), to: root) + "#" + format.openBlock, root: root, folder: chosenFolder(root: root),
                             vaultName: settings.obsidianVault, pathPrefix: settings.obsidianPathPrefix, obsidian: obsidian)
        }
    }

    private func markOpenTarget(_ id: String, in document: inout TaskDocument) {
        func mark(_ entries: inout [TaskEntry], in section: TaskSection?) {
            for index in entries.indices {
                // A habit's days in Done have its id too: its open line is the one to show.
                let isDayInDone = section == .done && entries[index].writesID
                entries[index].isOpenTarget = entries[index].id == id && !isDayInDone
                mark(&entries[index].children, in: section)
            }
        }
        for section in document.sections.indices where document.sections[section].kind != nil {
            for group in document.sections[section].groups.indices {
                mark(&document.sections[section].groups[group].entries, in: document.sections[section].kind)
            }
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
