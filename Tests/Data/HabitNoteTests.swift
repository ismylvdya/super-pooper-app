import Foundation
import Testing
@testable import SuperPooperApp

/// The app's settings of a habit (`habit_color`, `harmful`, `show_in_today`, …) live in one JSON property
/// (`fromSuperPooperApp`); notes with the older separate keys or property name are read and moved into it with the next change.
@Suite("Habit notes")
struct HabitNoteTests {
    @Test func habitOptionsRoundTripThroughTheSettingsProperty() async throws {
        let note = try await SandboxNote("Медитация 🧘")
        let written = try await note.apply([.habitColor("#34C759"), .harmful(true), .showInToday(false), .timeOfDay(.evening),
                                            .twiceADay(true), .twiceCountsDouble(true), .weeklyGoal(4)]).task
        let text = try note.text()
        let line = try #require(text.split(separator: "\n").first { $0.hasPrefix("fromSuperPooperApp: '{") })
        for pair in ["\"habit_color\":\"#34C759\"", "\"harmful\":true", "\"show_in_today\":false", "\"time_of_day\":\"evening\"",
                     "\"twice_a_day\":true", "\"twice_counts_double\":true", "\"weekly_goal\":4"] {
            #expect(line.contains(pair))
        }
        for key in ["habit_color:", "harmful:", "show_in_today:", "time_of_day:", "weekly_goal:", "reminder_times:"] {
            #expect(!text.split(separator: "\n").contains { $0.hasPrefix(key) }, "no separate \(key) key")
        }
        #expect(written.habit.color == "#34C759" && written.habit.harmful && !written.habit.showInToday)
        #expect(written.habit.timeOfDay == .evening && written.habit.skipRule == .weeklyGoal(times: 4))
    }

    /// A subtask's place among its parent's subtasks goes into the same JSON and is read back.
    @Test func theSubtaskPlaceIsKeptInTheSettingsProperty() async throws {
        let note = try await SandboxNote("Купить молоко")
        let written = try await note.apply([.subtaskOrder(2)]).task
        #expect(try note.text().contains("\"subtask_order\":2"))
        #expect(written.subtaskOrder == 2)
        #expect(try await note.apply([.subtaskOrder(nil)]).task.subtaskOrder == nil)
    }

    @Test func switchedOffOptionsLeaveTheNote() async throws {
        let note = try await SandboxNote("Медитация 🧘")
        _ = try await note.apply([.harmful(true), .weeklyGoal(3), .timeOfDay(.morning)])
        _ = try await note.apply([.harmful(false), .weeklyGoal(nil), .timeOfDay(nil)])
        let text = try note.text()
        #expect(!text.contains("harmful") && !text.contains("weekly_goal") && !text.contains("time_of_day"))
    }

    @Test func showInTodayIsAlwaysWrittenExplicitly() async throws {
        let note = try await SandboxNote("Медитация 🧘")
        _ = try await note.apply([.showInToday(true)])
        #expect(try note.text().contains("\"show_in_today\":true"))
    }

    /// Separate keys of an older note are read as before; the first settings change moves them into the JSON.
    @Test func olderSeparateKeysAreReadAndMovedIntoTheProperty() async throws {
        let note = try await SandboxNote("Медитация 🧘")
        let old = try note.text().replacingOnce("\ntags:", with: "\nhabit_color: \"#FF9500\"\nweekly_goal: 2\ntags:")
        try note.sandbox.write(old, to: note.task.name)
        let written = try await note.apply([.harmful(true)]).task
        let text = try note.text()
        #expect(written.habit.color == "#FF9500" && written.habit.skipRule == .weeklyGoal(times: 2) && written.habit.harmful)
        #expect(!text.contains("\nhabit_color:") && !text.contains("\nweekly_goal:"))
        #expect(text.contains("\"habit_color\":\"#FF9500\"") && text.contains("\"weekly_goal\":2"))
    }

    /// The sync's migration: the old property name, separate keys and the two feel booleans become the current
    /// fields, values unchanged.
    @Test func theMigrationRewritesEveryOlderField() async throws {
        let note = try await SandboxNote("Медитация 🧘")
        let old = try note.text().replacingOnce("\ntags:", with: """

        superpooper: '{"harmful":true}'
        habit_color: "#FF9500"
        need_energy: false
        pleasant: true
        tags:
        """)
        try note.sandbox.write(old, to: note.task.name)
        let before = try await note.reload()
        #expect(before.hasLegacyFields && before.feel == .pleasant && before.habit.harmful)
        let written = try await note.apply([.migrateLegacyFields]).task
        let text = try note.text()
        #expect(!written.hasLegacyFields && written.feel == .pleasant && written.habit.harmful && written.habit.color == "#FF9500")
        for key in ["superpooper:", "habit_color:", "need_energy:", "pleasant:"] {
            #expect(!text.split(separator: "\n").contains { $0.hasPrefix(key) }, "no \(key) key")
        }
        #expect(text.contains("\nfeel: pleasant\n") && text.contains("\"habit_color\":\"#FF9500\"") && text.contains("\"harmful\":true"))
    }
}

/// An edit that lands on a file changed elsewhere since the app read it.
@Suite("Write conflicts")
struct WriteConflictTests {
    @Test func aDifferentKeyChangedElsewhereMergesSilently() async throws {
        let note = try await SandboxNote("Купить молоко")
        try note.sandbox.write(try note.text().replacingOnce("time_estimate: 15", with: "time_estimate: 60"), to: note.task.name)
        let result = try await note.apply([.highPriority(true)])
        #expect(result.hadConflict && result.clashingKeys.isEmpty)
        #expect(result.task.timeEstimate == 60 && result.task.isHighPriority)
    }

    @Test func theSameKeyChangedElsewhereIsReported() async throws {
        let note = try await SandboxNote("Купить молоко")
        try note.sandbox.write(try note.text().replacingOnce("time_estimate: 15", with: "time_estimate: 60"), to: note.task.name)
        let result = try await note.apply([.timeEstimate(2)])
        #expect(result.clashingKeys == ["time_estimate"])
        #expect(result.task.timeEstimate == 2)
    }
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
        let url = VaultPaths.obsidianURL(relativePath: "Tasks/Купить молоко.md", root: folder, folder: ChosenFolder(),
                                         vaultName: "", pathPrefix: "", noteExtension: "md")
        let items = URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems
        #expect(items == [URLQueryItem(name: "vault", value: "Vault"), URLQueryItem(name: "file", value: "TaskNotes/Tasks/Купить молоко")])
        let custom = VaultPaths.obsidianURL(relativePath: "Tasks/A.md", root: folder, folder: ChosenFolder(),
                                            vaultName: "Main", pathPrefix: "Work/TaskNotes", noteExtension: "md")
        #expect(URLComponents(url: custom!, resolvingAgainstBaseURL: false)?.queryItems?.last?.value == "Work/TaskNotes/Tasks/A")
    }

    /// A TaskNotes folder deep in an iCloud vault: its path names the vault and where the folder is, no settings needed.
    @Test func theFolderInObsidiansICloudFolderTellsItsVault() throws {
        let vaults = "iCloud~md~obsidian/Documents"
        let nested = URL(fileURLWithPath: "/private/var/mobile/Library/Mobile Documents/iCloud~md~obsidian/Documents/Main/Work/TaskNotes",
                         isDirectory: true)
        let place = try #require(VaultPaths.obsidianPlace(of: nested, vaultsFolder: vaults))
        #expect(place == ObsidianPlace(vault: "Main", pathPrefix: "Work/TaskNotes"))
        let url = VaultPaths.obsidianURL(relativePath: "Tasks/A.md", root: nested, folder: ChosenFolder(obsidianPlace: place),
                                         vaultName: "", pathPrefix: "", noteExtension: "md")
        #expect(URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems
                == [URLQueryItem(name: "vault", value: "Main"), URLQueryItem(name: "file", value: "Work/TaskNotes/Tasks/A")])
        #expect(VaultPaths.obsidianPlace(of: folder, vaultsFolder: vaults) == nil)
    }

    @Test func aWholeVaultKeepsItsOwnPaths() async throws {
        let sandbox = try VaultSandbox.make()
        #expect(VaultPaths.isWholeVault(sandbox.vault, exists: { FileManager.default.fileExists(atPath: $0.path) }))
        let note = try await SandboxNote("Купить молоко", sandbox: sandbox)
        #expect(note.task.relativePath == "TaskNotes/Tasks/Купить молоко.md")
    }

    @Test func scanningTheTaskNotesFolderFindsTheTasks() async throws {
        let sandbox = try VaultSandbox.make()
        let root = sandbox.vault.appendingPathComponent("TaskNotes", isDirectory: true)
        let output = await sandbox.scanner().scan(root: root, tasksFolder: "TaskNotes/Tasks")
        #expect(output.result.tasks.contains { $0.relativePath == "Tasks/Купить молоко.md" })
        #expect(output.result.fileProblems.allSatisfy { if case .tasksFolderMissing = $0 { false } else { true } })
    }
}
