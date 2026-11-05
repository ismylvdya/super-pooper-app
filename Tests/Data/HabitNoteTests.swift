import Foundation
import Testing
@testable import SuperPooperApp

/// The app's settings of a habit (`habit_color`, `harmful`, `show_in_today`, …) live in one JSON property
/// (`fromSuperPooperApp`); notes with the older separate keys or property name are read and moved into it with the next change.
@Suite("Habit notes")
struct HabitNoteTests {
}

/// An edit that lands on a file changed elsewhere since the app read it.
@Suite("Write conflicts")
struct WriteConflictTests {
}

/// The app may be given the TaskNotes folder itself instead of the whole vault.
@Suite("TaskNotes folder access")
struct TaskNotesFolderTests {
    private let folder = URL(fileURLWithPath: "/iCloud/Vault/TaskNotes", isDirectory: true)

    @Test func theTasksFolderIsFoundFromTheTaskNotesFolder() {
        #expect(VaultPaths.tasksFolder("TaskNotes/Tasks", in: folder, exists: { _ in false }) == "Tasks")
        #expect(VaultPaths.tasksFolder("TaskNotes/Tasks", in: folder, exists: { _ in true }) == "TaskNotes/Tasks")
        let vault = URL(fileURLWithPath: "/iCloud/Vault", isDirectory: true)
        #expect(VaultPaths.tasksFolder("TaskNotes/Tasks", in: vault, exists: { _ in false }) == "TaskNotes/Tasks")
    }

    @Test func obsidianLinksPointIntoTheVault() {
        let url = ObsidianLink.url(relativePath: "Tasks/Купить молоко.md", root: folder, folder: ChosenFolder(),
                                         vaultName: "", pathPrefix: "", obsidian: TestConfig.obsidian)
        let items = URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems
        #expect(items == [URLQueryItem(name: "vault", value: "Vault"), URLQueryItem(name: "file", value: "TaskNotes/Tasks/Купить молоко")])
        let custom = ObsidianLink.url(relativePath: "Tasks/A.md", root: folder, folder: ChosenFolder(),
                                            vaultName: "Main", pathPrefix: "Work/TaskNotes", obsidian: TestConfig.obsidian)
        #expect(URLComponents(url: custom!, resolvingAgainstBaseURL: false)?.queryItems?.last?.value == "Work/TaskNotes/Tasks/A")
    }

    /// A TaskNotes folder deep in an iCloud vault: its path names the vault and where the folder is, no settings needed.
    @Test func theFolderInObsidiansICloudFolderTellsItsVault() throws {
        let vaults = TestConfig.obsidian.vaultsFolder
        let nested = URL(fileURLWithPath: "/private/var/mobile/Library/Mobile Documents/iCloud~md~obsidian/Documents/Main/Work/TaskNotes",
                         isDirectory: true)
        let place = try #require(VaultPaths.obsidianPlace(of: nested, vaultsFolder: vaults))
        #expect(place == ObsidianPlace(vault: "Main", pathPrefix: "Work/TaskNotes"))
        let url = ObsidianLink.url(relativePath: "Tasks/A.md", root: nested, folder: ChosenFolder(obsidianPlace: place),
                                         vaultName: "", pathPrefix: "", obsidian: TestConfig.obsidian)
        #expect(URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems
                == [URLQueryItem(name: "vault", value: "Main"), URLQueryItem(name: "file", value: "Work/TaskNotes/Tasks/A")])
        #expect(VaultPaths.obsidianPlace(of: folder, vaultsFolder: vaults) == nil)
    }

}
