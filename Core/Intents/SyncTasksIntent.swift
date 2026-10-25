import AppIntents

/// The "Sync Tasks" action for Shortcuts: re-reads the vault, Calendar and Reminders, then updates
/// widgets and notifications. Meant for automations ("when Reminders or Calendar is closed").
/// It runs in the app's process; the app installs the handler at launch.
struct SyncTasksIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.sync.title"
    static let description = IntentDescription("intent.sync.description")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await AppActionBridge.sync()
        return .result()
    }
}
