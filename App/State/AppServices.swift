import Foundation
import WidgetKit

/// Everything the app state talks to, created once in the composition root.
struct AppServices {
    let vault: VaultLocating
    let tasks: TaskRepository
    let calendars: CalendarRepository
    let reminders: RemindersRepository
    let notifications: NotificationScheduling
    let settingsStore: SettingsStore
    let dayStateStore: DayStateStore
    let snapshotStore: SnapshotStore
    let widgets: WidgetReloading
}

protocol WidgetReloading: Sendable {
    func reloadAll()
}

struct WidgetKitReloader: WidgetReloading {
    func reloadAll() { WidgetCenter.shared.reloadAllTimelines() }
}
