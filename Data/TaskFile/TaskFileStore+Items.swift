import Foundation

/// Writing items: a task is its line, a habit its JSON file and its lines in Done.
extension TaskFileStore {
    func apply(_ changes: [TaskEdit], to task: TaskItem) async throws -> TaskWriteResult {
        try await location.withRoot { root in
            var snapshot = try await read(root: root)
            let id = task.id.value
            if var file = snapshot.habits[id] {
                let updated = habit(of: file, snapshot: snapshot).applying(changes)
                file.update(from: updated)
                for case .addProject(let name) in changes { file.parent = snapshot.id(ofName: name) }
                for case .mark(let mark, let day) in changes { snapshot.document.setMark(mark, on: day, habit: id, name: file.name) }
                try write(file, root: root)
                try write(snapshot.document, root: root)
                snapshot.habits[id] = file
                return TaskWriteResult(task: habit(of: file, snapshot: snapshot), hadConflict: false)
            }
            try update(id: id, name: task.name, changes: changes, in: &snapshot)
            try write(snapshot.document, root: root)
            snapshot.indexNames()
            return TaskWriteResult(task: try current(id: id, name: task.name, snapshot: snapshot), hadConflict: false)
        }
    }

    /// The task on its line: in place while it stays in its section under its parent, otherwise moved with its subtasks.
    private func update(id: String, name: String, changes: [TaskEdit], in snapshot: inout Snapshot) throws {
        let was = try current(id: id, name: name, snapshot: snapshot)
        let updated = was.applying(changes)
        guard let place = place(of: id, in: snapshot.document) else { throw TaskStoreError.fileMissing(name) }
        let target = TaskSection.of(updated, current: place.section, today: today(), boundary: boundary())
        let parent = updated.projects.first.flatMap(snapshot.id(ofName:))
        let order = changes.compactMap { change -> Int?? in if case .subtaskOrder(let value) = change { value } else { nil } }.last
        if target == place.section, parent == place.parent ?? place.tag, order == nil {
            snapshot.document.update(id: id) { $0.update(from: updated, format: format) }
            return
        }
        guard var taken = snapshot.document.remove(where: { $0.id == id })?.entry else { throw TaskStoreError.fileMissing(name) }
        taken.update(from: updated, format: format)
        taken.parent = nil
        if let parent {
            if self.place(of: parent, in: snapshot.document)?.section == target,
               snapshot.document.insert(taken, under: parent, at: order.flatMap { $0 }) { return }
            taken.parent = parent
        }
        snapshot.document.insert(taken, into: target)
    }

    private func current(id: String, name: String, snapshot: Snapshot) throws -> TaskItem {
        guard let place = place(of: id, in: snapshot.document) else { throw TaskStoreError.fileMissing(name) }
        return item(place.entry, in: place.section, parent: place.parentEntry, index: place.index, snapshot: snapshot)
    }

    func place(of id: String, in document: TaskDocument) -> (entry: TaskEntry, section: TaskSection, parentEntry: TaskEntry?, parent: String?, tag: String?, index: Int)? {
        var found: (TaskEntry, TaskSection, TaskEntry?, String?, String?, Int)?
        document.walk { entry, section, parent, index in
            if found == nil, entry.id == id { found = (entry, section, parent, parent?.id, entry.parent, index) }
        }
        return found
    }

    /// A new line or a new habit with every field of the draft and its text, under a free name.
    func create(_ draft: NoteDraft, named name: String) async throws -> TaskItem {
        guard nameProblem(in: name) == nil else { throw TaskStoreError.invalidName(name) }
        return try await location.withRoot { root in
            var snapshot = try await read(root: root)
            let final = UniqueName.free(name) { snapshot.isTaken($0) }
            let id = makeID()
            var note = draft.note
            note.name = final
            note.id = TaskID(id)
            let parent = note.projects.first.flatMap(snapshot.id(ofName:))
            if note.isHabit {
                // A repeat with no day of its own starts from today: its first day is the nearest one that fits.
                note.recurrence = note.recurrence.map { $0.startDate == nil ? $0.starting(today()) : $0 }
                let file = HabitFile(id: id, item: note, parent: parent, note: draft.body)
                try write(file, root: root)
                snapshot.habits[id] = file
                snapshot.indexNames()
                return habit(of: file, snapshot: snapshot)
            }
            var entry = TaskEntry(name: final)
            entry.id = id
            entry.update(from: note, format: format)
            entry.note = Self.lines(of: draft.body)
            let target = TaskSection.of(note, current: .now, today: today(), boundary: boundary())
            if let parent {
                if place(of: parent, in: snapshot.document)?.section == target, snapshot.document.insert(entry, under: parent) {
                    try write(snapshot.document, root: root)
                    snapshot.indexNames()
                    return try current(id: id, name: final, snapshot: snapshot)
                }
                entry.parent = parent
            }
            snapshot.document.insert(entry, into: target)
            try write(snapshot.document, root: root)
            snapshot.indexNames()
            return try current(id: id, name: final, snapshot: snapshot)
        }
    }

    /// Items refer to each other by ids, so the others keep following it (`dependents` need nothing).
    func rename(_ task: TaskItem, to newName: String, dependents: [TaskItem]) async throws -> TaskItem {
        guard nameProblem(in: newName) == nil else { throw TaskStoreError.invalidName(newName) }
        return try await location.withRoot { root in
            var snapshot = try await read(root: root)
            let id = task.id.value
            if snapshot.isTaken(newName, except: id) { throw TaskStoreError.nameTaken(newName) }
            func rename(_ entries: inout [TaskEntry]) {
                for index in entries.indices {
                    if entries[index].id == id { entries[index].name = newName }
                    rename(&entries[index].children)
                }
            }
            // A habit's days in Done keep the name they were done under: they go by the id.
            let isHabit = snapshot.habits[id] != nil
            for section in snapshot.document.sections.indices where !(isHabit && snapshot.document.sections[section].kind == .done) {
                for group in snapshot.document.sections[section].groups.indices { rename(&snapshot.document.sections[section].groups[group].entries) }
            }
            if var file = snapshot.habits[id] {
                file.name = newName
                try write(file, root: root)
                snapshot.habits[id] = file
            } else if place(of: id, in: snapshot.document) == nil {
                throw TaskStoreError.fileMissing(task.name)
            }
            try write(snapshot.document, root: root)
            var result = task
            result.name = newName
            return result
        }
    }

    func text(of task: TaskItem) async throws -> String {
        try await location.withRoot { root in
            let snapshot = try await read(root: root)
            if let file = snapshot.habits[task.id.value] { return file.note }
            guard let entry = snapshot.document.entry(id: task.id.value) else { throw TaskStoreError.fileMissing(task.name) }
            return entry.note.joined(separator: "\n")
        }
    }

    func setText(_ text: String, of task: TaskItem) async throws -> TaskWriteResult {
        try await location.withRoot { root in
            var snapshot = try await read(root: root)
            let id = task.id.value
            if var file = snapshot.habits[id] {
                file.note = text
                try write(file, root: root)
                return TaskWriteResult(task: task, hadConflict: false)
            }
            guard snapshot.document.update(id: id, { $0.note = Self.lines(of: text) }) else { throw TaskStoreError.fileMissing(task.name) }
            try write(snapshot.document, root: root)
            return TaskWriteResult(task: task, hadConflict: false)
        }
    }

    static func lines(of text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .newlines)
        return trimmed.isEmpty ? [] : trimmed.components(separatedBy: "\n")
    }

    // MARK: - Done

    /// To the top of Done, with its subtasks.
    func fileAway(_ task: TaskItem) async throws -> TaskItem {
        try await location.withRoot { root in
            var snapshot = try await read(root: root)
            guard var taken = snapshot.document.remove(where: { $0.id == task.id.value })?.entry else { throw TaskStoreError.fileMissing(task.name) }
            taken.box = .done
            taken.completed = taken.completed ?? today()
            taken.isOverdue = false
            snapshot.document.insert(taken, into: .done, atTop: true)
            try write(snapshot.document, root: root)
            var filed = task
            filed.status = .done
            filed.completedDate = taken.completed
            return filed
        }
    }

    func filedTasks() async throws -> [TaskItem] {
        try await location.withRoot { root in
            var snapshot = try await read(root: root)
            snapshot.indexNames()
            var tasks: [TaskItem] = []
            snapshot.document.walk { entry, section, parent, index in
                guard section == .done, let id = entry.id, snapshot.habits[id] == nil else { return }
                tasks.append(item(entry, in: section, parent: parent, index: index, snapshot: snapshot))
            }
            return tasks
        }
    }

    /// Back into Now, open; a name taken meanwhile gets a number.
    func unfile(_ task: TaskItem) async throws -> TaskItem {
        try await location.withRoot { root in
            var snapshot = try await read(root: root)
            guard var taken = snapshot.document.remove(where: { $0.id == task.id.value })?.entry else { throw TaskStoreError.fileMissing(task.name) }
            snapshot.indexNames()
            taken.name = UniqueName.free(taken.name) { snapshot.isTaken($0) }
            taken.box = .open
            taken.completed = nil
            snapshot.document.insert(taken, into: .now)
            try write(snapshot.document, root: root)
            snapshot.indexNames()
            return try current(id: task.id.value, name: taken.name, snapshot: snapshot)
        }
    }

    // MARK: - Import

    func importItems(_ imported: [ImportedItem]) async throws -> Int {
        try await location.withRoot { root in
            var snapshot = try await read(root: root)
            var marks: [(day: LocalDate, mark: HabitMark, id: String, name: String)] = []
            var pending: [(id: String, source: ImportedItem)] = []
            // An import can be repeated: what it brought into Done last time is not brought again.
            var filed: Set<NoteName> = []
            snapshot.document.walk { entry, section, _, _ in if section == .done { filed.insert(entry.name.noteName) } }
            for source in imported where !snapshot.isTaken(source.item.name) && !filed.contains(source.item.name.noteName) {
                let id = makeID()
                snapshot.names[id] = source.item.name
                pending.append((id, source))
            }
            let parentID = { (item: TaskItem) -> String? in
                item.projects.first.flatMap { snapshot.id(ofName: $0) }
            }
            // Parents first: a subtask's line goes under its parent's.
            let order = pending.sorted { $0.source.item.projects.isEmpty && !$1.source.item.projects.isEmpty }
            for (id, source) in order {
                var item = source.item
                item.id = TaskID(id)
                if item.isHabit {
                    try write(HabitFile(id: id, item: item, parent: parentID(item), note: source.text), root: root)
                    marks += item.marks.map { ($0.key, $0.value, id, item.name) }
                    continue
                }
                var entry = TaskEntry(name: item.name)
                entry.id = id
                entry.update(from: item, format: format)
                entry.note = Self.lines(of: source.text)
                let target: TaskSection = source.isFiled ? .done : TaskSection.of(item, current: .now, today: today(), boundary: boundary())
                if let parent = parentID(item), place(of: parent, in: snapshot.document)?.section == target,
                   snapshot.document.insert(entry, under: parent) { continue }
                entry.parent = parentID(item)
                snapshot.document.insert(entry, into: target, atTop: source.isFiled)
            }
            for mark in marks.sorted(by: { $0.day < $1.day }) {
                snapshot.document.setMark(mark.mark, on: mark.day, habit: mark.id, name: mark.name)
            }
            try write(snapshot.document, root: root)
            return pending.count
        }
    }
}
