import Foundation

/// Puts what the app state reports into banners: the words, the style, the counts and notes under the text, and the
/// page a tap opens. The only place that knows how an event looks.
@MainActor
final class BannerPresenter: AppEventSink {
    private let banners: BannerCenter

    init(banners: BannerCenter) {
        self.banners = banners
    }

    func send(_ event: AppEvent) {
        banners.show(Self.banner(for: event))
    }

    static func banner(for event: AppEvent) -> BannerCenter.Banner {
        switch event {
        case .created(let name): success("banner.created", name)
        case .renamed(let name): success("banner.renamed", name)
        case .archived(let name): success("banner.archived", name)
        case .deleted(let name): success("banner.deleted", name)
        case .restored(let name): success("banner.restored", name)
        case .deletedForever(let name): success("banner.deletedForever", name)
        case .conflictResolved(let name): success("banner.conflictResolved", name)
        case .promoted(let names):
            BannerCenter.Banner(text: L10n.string("banner.promoted"), style: .success, items: names)
        case .fieldsClashed(let name, let fields):
            BannerCenter.Banner(text: L10n.format("banner.conflictSameKey", name), style: .warning,
                                items: fields.map(TaskFieldText.title))
        case .conflictsFound(let names):
            BannerCenter.Banner(text: L10n.string("banner.conflict"), style: .warning,
                                opens: BannerTarget(tab: .settings, routes: [.conflicts]), items: names)
        case .synced(let added, let changed, let removed):
            synced(added: added, changed: changed, removed: removed)
        case .problemsFound(let count):
            BannerCenter.Banner(text: L10n.format("banner.problems", count), style: .problem)
        case .wholeVaultChosen:
            BannerCenter.Banner(text: L10n.string("banner.wholeVault"), style: .warning)
        case .orderReset:
            BannerCenter.Banner(text: L10n.string("banner.orderReset"))
        case .nameRejected(let problem, let name):
            BannerCenter.Banner(text: NoteNameProblemText.describe(problem, name: name), style: .problem)
        case .notificationImageFailed:
            BannerCenter.Banner(text: L10n.string("banner.notificationImageFailed"), style: .warning)
        case .failure(let failure):
            BannerCenter.Banner(text: FailureText.describe(failure), style: .problem)
        }
    }

    private static func success(_ key: String, _ name: String) -> BannerCenter.Banner {
        BannerCenter.Banner(text: L10n.format(key, name), style: .success)
    }

    /// "Synced" and a count per kind of change, each its own element; the kinds without one are left out.
    private static func synced(added: Int, changed: Int, removed: Int) -> BannerCenter.Banner {
        let counts = [(Icon.syncAdded, added, "banner.sync.added"), (.syncChanged, changed, "banner.sync.changed"),
                      (.syncRemoved, removed, "banner.sync.removed")]
            .filter { $0.1 > 0 }
            .map { BannerCount(icon: $0.0, value: $0.1, label: L10n.format($0.2, $0.1)) }
        let text = counts.isEmpty ? L10n.string("banner.sync.upToDate") : L10n.string("banner.sync.changes")
        return BannerCenter.Banner(text: text, style: .synced, counts: counts)
    }
}
