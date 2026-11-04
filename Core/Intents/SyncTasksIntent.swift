import AppIntents

/// The "Sync All" action for Shortcuts, the same sync as a pull: re-reads the vault, Calendar and Reminders, then updates
/// widgets and notifications. The type keeps its old name: shortcuts that already use the action go on working. Meant for automations ("when Reminders or Calendar is closed").
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
