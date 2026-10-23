import Foundation
import Observation

/// Messages shown in the top banner after actions and syncs (never pushes).
@MainActor
@Observable
final class BannerCenter {
    struct Banner: Identifiable, Equatable {
        enum Style: Equatable {
            /// Sync finished.
            case synced
            case info
            case success
            case problem
        }

        let id = UUID()
        let text: String
        let style: Style
    }

    private(set) var current: Banner?
    private var queue: [Banner] = []

    func show(_ text: String, style: Banner.Style = .info) {
        let banner = Banner(text: text, style: style)
        if current == nil { current = banner } else { queue.append(banner) }
    }

    func dismiss(_ id: UUID) {
        guard current?.id == id else { return }
        current = queue.isEmpty ? nil : queue.removeFirst()
    }
}
