import Foundation

/// What a sync changed, for the event after pull-to-refresh.
struct SyncReport {
    var added: [String] = []
    var changed: [String] = []
    var removed: [String] = []
    var promoted: [String] = []
    var conflicts: [String] = []

    init() {}

    init(old: [TaskItem], new: [TaskItem]) {
        let oldByName = Dictionary(old.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let newByName = Dictionary(new.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        added = newByName.keys.filter { oldByName[$0] == nil }.sorted()
        removed = oldByName.keys.filter { newByName[$0] == nil }.sorted()
        changed = newByName.compactMap { name, task in
            guard let previous = oldByName[name], previous.withoutTimestamps != task.withoutTimestamps else { return nil }
            return name
        }.sorted()
    }
}

private extension TaskItem {
    var withoutTimestamps: TaskItem {
        var copy = self
        copy.dateModified = nil
        return copy
    }
}
