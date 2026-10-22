import Foundation

/// What a sync changed, for the banner after pull-to-refresh.
struct SyncReport {
    var added: [String] = []
    var changed: [String] = []
    var removed: [String] = []
    var promoted: [String] = []
    var conflicts: [String] = []

    init() {}

    init(old: [TaskNote], new: [TaskNote]) {
        let oldByName = Dictionary(old.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let newByName = Dictionary(new.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        added = newByName.keys.filter { oldByName[$0] == nil }.sorted()
        removed = oldByName.keys.filter { newByName[$0] == nil }.sorted()
        changed = newByName.compactMap { name, task in
            guard let previous = oldByName[name], previous.withoutTimestamps != task.withoutTimestamps else { return nil }
            return name
        }.sorted()
    }

    var summary: String {
        guard !added.isEmpty || !changed.isEmpty || !removed.isEmpty else { return L10n.string("banner.sync.upToDate") }
        return L10n.format("banner.sync.changes", added.count, changed.count, removed.count)
    }
}

private extension TaskNote {
    var withoutTimestamps: TaskNote {
        var copy = self
        copy.dateModified = nil
        return copy
    }
}
