import Foundation

/// Everything the app state talks to, created once in the composition root.
struct AppServices {
    let vault: VaultLocating
    let tasks: TaskRepository
    let trash: TrashRepository
    let settingsNote: SettingsNoteRepository
    let calendars: CalendarRepository
    let reminders: RemindersRepository
    let notifications: NotificationScheduling
    let settingsStore: SettingsStore
    let dayStateStore: DayStateStore
    let snapshotStore: SnapshotStore
    let alertStateStore: AlertStateStore
    let widgets: WidgetReloading
    let notificationImage: NotificationImageStore
}
