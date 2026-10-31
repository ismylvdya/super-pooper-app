import Foundation

/// What a sync changed, for the banner after pull-to-refresh.
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

    /// The banner's message: "Synced" and a count per kind of change, the kinds without one left out.
    var summary: String {
        counts.isEmpty ? L10n.string("banner.sync.upToDate") : L10n.string("banner.sync.changes")
    }

    var counts: [BannerCount] {
        [(Icon.syncAdded, added, "banner.sync.added"), (.syncChanged, changed, "banner.sync.changed"), (.syncRemoved, removed, "banner.sync.removed")]
            .filter { !$0.1.isEmpty }
            .map { BannerCount(icon: $0.0, value: $0.1.count, label: L10n.format($0.2, $0.1.count)) }
    }
}

private extension TaskItem {
    var withoutTimestamps: TaskItem {
        var copy = self
        copy.dateModified = nil
        return copy
    }
}
