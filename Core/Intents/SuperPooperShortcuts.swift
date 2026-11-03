import AppIntents

struct SuperPooperShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SyncTasksIntent(), phrases: ["Sync tasks in \(.applicationName)"],
                    shortTitle: "intent.sync.title", systemImageName: "arrow.triangle.2.circlepath")
        AppShortcut(intent: CheckSigningIntent(), phrases: ["Check signature of \(.applicationName)"],
                    shortTitle: "intent.signing.title", systemImageName: "signature")
    }
}
