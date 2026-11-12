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

            /// Good or neutral news (green): nothing to do about it.
            var isGood: Bool {
                switch self {
                case .info, .synced, .success: true
                case .warning, .problem: false
                }
            }
        }

        /// How long it stays (`rules.json` → `banners`): good news without Undo only a moment, the rest longer.
        func seconds(_ rules: RulesConfig.Banners) -> Double {
            if undo != nil { return rules.undoSeconds }
            return style.isGood ? rules.goodNewsSeconds : rules.autoHideSeconds
        }

        let id = UUID()
        let text: String
        var style: Style = .info
        /// Tapping the banner opens this page instead of expanding the text.
        var opens: BannerTarget?
        /// Under the text: a count per kind, and the notes the message is about, each on its own line.
        var counts: [BannerCount] = []
        var items: [String] = []
        /// The banner offers to take an action back (`UndoOffer`) while it is shown.
        var undo: UUID?
    }

    /// The banners shown, oldest first: a new one comes on top at once, each leaves after its own time, and what is
    /// under the one that left shows again.
    private(set) var stack: [Banner] = []

    /// The banner on top.
    var current: Banner? { stack.last }

    func show(_ banner: Banner) {
        stack.append(banner)
    }

    func dismiss(_ id: UUID) {
        stack.removeAll { $0.id == id }
    }
}

/// The page a banner opens: a tab and the pages pushed on it.
struct BannerTarget: Equatable {
    let tab: AppTab
    var routes: [Route] = []
}
