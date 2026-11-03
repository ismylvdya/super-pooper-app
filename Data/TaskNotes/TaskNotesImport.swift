import Foundation

/// Reads a TaskNotes folder once, for the import into the tasks file: every task and habit with its text, and what was put
/// away in its Done folder. The folder is only read and stays as it is.
enum TaskNotesImport {
    static func items(from folder: URL, mapping: FieldMapping, calendar: CalendarSource, rules: RulesConfig.Vault, backups: BackupService,
                      clock: Clock, vault: AppSettings.Vault) async throws -> [ImportedItem] {
        let isScoped = folder.startAccessingSecurityScopedResource()
        defer { if isScoped { folder.stopAccessingSecurityScopedResource() } }
        let store = TaskNotesStore(location: FixedVaultLocation(url: folder), fileSystem: CoordinatedFileSystem(), ubiquity: ICloudUbiquityService(),
                                   mapping: mapping, calendar: calendar, rules: rules, backups: backups, clock: clock, vaultSettings: { vault })
        var items: [ImportedItem] = []
        for task in try await store.load().tasks {
            items.append(ImportedItem(item: task, text: (try? await store.text(of: task)) ?? "", isFiled: task.status == .done))
        }
        for task in try await store.filedTasks() {
            items.append(ImportedItem(item: task, text: (try? await store.text(of: task)) ?? "", isFiled: true))
        }
        return items
    }
}
