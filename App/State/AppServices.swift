import Foundation

/// Everything the app state talks to, created once in the composition root.
struct AppServices {
    let vault: VaultLocating
    let tasks: TaskStore
    /// What the task store can do beyond the basics; nil where it cannot, and the app leaves that feature out.
    let trash: TaskTrash?
    let versions: VersionConflictResolving?
    let links: ExternalLinking?
    let backups: TaskBackups?
    let folder: FolderInspecting?
    /// Keeps the store's own look of today in step with the app's.
    var mirroring: DayMirroring? = nil
    /// Takes the items of an old TaskNotes folder into the store.
    var importer: TaskImporting? = nil
    var readTaskNotes: (@Sendable (URL) async throws -> [ImportedItem])? = nil
    let settingsNote: SettingsNoteRepository
    let calendars: CalendarRepository
    let reminders: RemindersRepository
    let notifications: NotificationScheduling
    let settingsStore: SettingsStore
    let dayStateStore: DayStateStore
    let daySectionStore: DaySectionStorage
    let snapshotStore: SnapshotStore
    let alertStateStore: AlertStateStore
    let snoozeStore: SnoozeStore
    let widgets: WidgetReloading
    let notificationImage: NotificationImageStore
    let signature: AppSignatureReading
}
