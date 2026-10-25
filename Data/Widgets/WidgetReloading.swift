import WidgetKit

/// Asks the system to redraw the widgets after the snapshot changed.
protocol WidgetReloading: Sendable {
    func reloadAll()
}

struct WidgetKitReloader: WidgetReloading {
    func reloadAll() { WidgetCenter.shared.reloadAllTimelines() }
}
