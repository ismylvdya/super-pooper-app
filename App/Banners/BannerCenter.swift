import Foundation
import Observation

/// Messages shown in the top banner after actions and syncs (never pushes). They come from the app state's events,
/// put into words by `BannerPresenter`.
@MainActor
@Observable
final class BannerCenter {
    struct Banner: Identifiable, Equatable {
        enum Style: Equatable {
            /// Sync finished.
            case synced
            case info
            case success
            /// Something needs attention but nothing failed (e.g. a note changed in two places).
            case warning
            case problem
        }

        let id = UUID()
        let text: String
        var style: Style = .info
        /// Tapping the banner opens this page instead of expanding the text.
        var opens: BannerTarget?
        /// Under the text: a count per kind, and the notes the message is about, each on its own line.
        var counts: [BannerCount] = []
        var items: [String] = []
    }

    private(set) var current: Banner?
    private var queue: [Banner] = []

    func show(_ banner: Banner) {
        if current == nil { current = banner } else { queue.append(banner) }
    }

    func dismiss(_ id: UUID) {
        guard current?.id == id else { return }
        current = queue.isEmpty ? nil : queue.removeFirst()
    }
}

/// The page a banner opens: a tab and the pages pushed on it.
struct BannerTarget: Equatable {
    let tab: AppTab
    var routes: [Route] = []
}
