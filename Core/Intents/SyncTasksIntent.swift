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

/// Connects intents to the app model without the shared code knowing the app.
@MainActor
enum AppActionBridge {
    static var syncHandler: (() async -> Void)?

    static func sync() async {
        await syncHandler?()
    }
}

struct SuperPooperShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SyncTasksIntent(), phrases: ["Sync tasks in \(.applicationName)"],
                    shortTitle: "intent.sync.title", systemImageName: "arrow.triangle.2.circlepath")
    }
}
