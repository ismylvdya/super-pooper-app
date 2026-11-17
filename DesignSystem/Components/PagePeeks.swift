import SwiftUI

/// On pages (`ScreenLayout.isPaged`): how much of the screen's width each day's page keeps in sight while the other is
/// shown — the pool beside the timeline, the timeline beside the pool (`AppSettings.Today`, D-191).
struct PagePeeks: Equatable, Sendable {
    var pool: Double
    var timeline: Double

    init(pool: Double, timeline: Double) {
        self.pool = pool
        self.timeline = timeline
    }

    init(_ today: AppSettings.Today) {
        self.init(pool: today.poolPeek, timeline: today.timelinePeek)
    }

    /// The share of the width `block`'s page keeps in sight.
    func share(of block: TodayBlockID) -> Double {
        switch block {
        case .pool: pool
        case .timeline: timeline
        }
    }
}

private struct PagePeeksKey: EnvironmentKey {
    static let defaultValue = PagePeeks(pool: 0, timeline: 0)
}

extension EnvironmentValues {
    /// The settings' page peeks, for every paged layout drawn (Tasks, the settings' preview).
    var pagePeeks: PagePeeks {
        get { self[PagePeeksKey.self] }
        set { self[PagePeeksKey.self] = newValue }
    }
}
