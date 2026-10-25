import Foundation
import Testing
@testable import SuperPooper

/// iCloud Drive specifics with a fake ubiquity service (`<data_model>` "Доступ к vault", "Конфликт правок").
/// Real iCloud can't be exercised in the simulator, so these fakes are the only check of this behaviour.
@Suite("iCloud behaviour")
struct ICloudTests {
    @Test func aFileThatNeverDownloadsBecomesAProblemAfterTheTimeout() async throws {
        let sandbox = try VaultSandbox.make()
        let ubiquity = FakeUbiquityService()
        ubiquity.evict("Найти отвёртку.md")
        try Data().write(to: sandbox.tasksFolder.appendingPathComponent(".Облачная задача.md.icloud"))

        let started = Date()
        let result = await sandbox.scan(ubiquity: ubiquity, downloadTimeout: 0.3)

        #expect(Date().timeIntervalSince(started) < 10)
        #expect(Set(result.fileProblems.filter { if case .notDownloaded = $0 { true } else { false } })
            == [.notDownloaded(file: "Найти отвёртку"), .notDownloaded(file: "Облачная задача")])
        #expect(Set(ubiquity.downloadRequests) == ["Найти отвёртку.md", "Облачная задача.md"])
        #expect(result.tasks.count == 35)
        #expect(!result.tasks.contains { $0.name == "Найти отвёртку" })
    }

    @Test func aPlaceholderThatFinishesDownloadingIsRead() async throws {
        let sandbox = try VaultSandbox.make()
        let content = try sandbox.text(of: "Купить молоко")
        let placeholder = sandbox.tasksFolder.appendingPathComponent(".Купить молоко.md.icloud")
        try FileManager.default.moveItem(at: sandbox.url(of: "Купить молоко"), to: placeholder)
        let ubiquity = FakeUbiquityService()
        ubiquity.willDownload("Купить молоко.md", content: content)

        let result = await sandbox.scan(ubiquity: ubiquity, downloadTimeout: 5)

        #expect(ubiquity.downloadRequests == ["Купить молоко.md"])
        #expect(result.fileProblems.count == 1)
        let milk = try #require(result.tasks.first { $0.name == "Купить молоко" })
        #expect(milk.status == .done && milk.completedDate == LocalDate("2026-10-21"))
        #expect(milk.relativePath == "TaskNotes/Tasks/Купить молоко.md")
        #expect(result.tasks.count == 36)
    }

    @Test func downloadedFilesAreNotRequestedAgain() async throws {
        let ubiquity = FakeUbiquityService()
        _ = try await VaultSandbox.make().scan(ubiquity: ubiquity)
        #expect(ubiquity.downloadRequests.isEmpty)
    }

    @Test func conflictVersionsAreReportedNotResolved() async throws {
        let sandbox = try VaultSandbox.make()
        let ubiquity = FakeUbiquityService()
        ubiquity.conflict("Сдать отчёт.md")
        ubiquity.conflict("Медитация 🧘.md")

        let result = await sandbox.scan(ubiquity: ubiquity)

        #expect(Set(result.conflicted) == ["Сдать отчёт", "Медитация 🧘"])
        #expect(result.tasks.count == 36)
    }

    /// Only tasks get to the conflicts screen: a plain note in conflict there could never be resolved.
    @Test func conflictsOfNotesThatAreNotTasksAreNotReported() async throws {
        let sandbox = try VaultSandbox.make()
        try "# Просто заметка\n".write(to: sandbox.url(of: "Просто заметка"), atomically: true, encoding: .utf8)
        let ubiquity = FakeUbiquityService()
        ubiquity.conflict("Просто заметка.md")
        ubiquity.conflict("Сдать отчёт.md")
        #expect(await sandbox.scan(ubiquity: ubiquity).conflicted == ["Сдать отчёт"])
    }

    @Test func aLocalVaultSkipsTheICloudChecks() async throws {
        let sandbox = try VaultSandbox.make()
        let ubiquity = FakeUbiquityService()
        ubiquity.makeLocal()
        ubiquity.evict("Найти отвёртку.md")
        ubiquity.conflict("Сдать отчёт.md")

        let result = await sandbox.scan(ubiquity: ubiquity, downloadTimeout: 5)

        #expect(result.tasks.count == 36)
        #expect(result.conflicted.isEmpty && ubiquity.conflictChecks.isEmpty)
        #expect(ubiquity.downloadRequests.isEmpty)
        #expect(result.fileProblems.count == 1)
    }

    // MARK: - Writes

    @Test func aWriteWithoutOutsideChangesIsNotAConflict() async throws {
        let note = try await SandboxNote("Найти отвёртку")
        #expect(try await note.apply([.highPriority(true)]).hadConflict == false)
        #expect(try await note.apply([.needEnergy(true)]).hadConflict == false)
    }

    @Test func aFileChangedElsewhereSinceTheScanIsAConflictAndTheLatestVersionWins() async throws {
        let note = try await SandboxNote("Найти отвёртку")
        let fromMac = try note.text()
            .replacingOnce("time_estimate: 15\n", with: "time_estimate: 60\n")
            + "Дописано на Mac\n"
        try writeElsewhere(fromMac, to: note)

        let result = try await note.apply([.highPriority(true)])

        #expect(result.hadConflict)
        expectSameBytes(try note.text(), try fromMac
            .replacingOnce("priority: none\n", with: "priority: high\n")
            .replacingOnce("date_modified: 2026-10-20T09:12:44.123+02:00", with: "date_modified: \(note.sandbox.nowStamp)"))
        #expect(result.task.isHighPriority && result.task.timeEstimate == 60)
        #expect(try await note.apply([.needEnergy(true)]).hadConflict == false)
    }

    @Test func conflictVersionsFoundAtWriteTimeAreReported() async throws {
        let ubiquity = FakeUbiquityService()
        let note = try await SandboxNote("Найти отвёртку", ubiquity: ubiquity)
        ubiquity.conflict("Найти отвёртку.md")
        let result = try await note.apply([.highPriority(true)])
        #expect(result.hadConflict)
        #expect(try note.text().contains("priority: high\n"))
    }

    @Test func theUserKeepsTheVersionTheyPick() async throws {
        let ubiquity = FakeUbiquityService()
        let note = try await SandboxNote("Найти отвёртку", ubiquity: ubiquity)
        let fromMac = try note.text().replacingOnce("priority: none\n", with: "priority: high\n")
        ubiquity.conflict("Найти отвёртку.md", versions: [fromMac])

        let versions = try await note.repository.versions(of: note.task)
        #expect(versions.count == 2 && versions[0].isCurrent && versions[1].text == fromMac)

        try await note.repository.keep(versions[1].id, of: note.task)
        #expect(try note.text() == fromMac)
        #expect(!ubiquity.hasConflicts(note.sandbox.url(of: note.task.name)))
    }

    @Test func keepingTheCurrentVersionLeavesTheFile() async throws {
        let ubiquity = FakeUbiquityService()
        let note = try await SandboxNote("Найти отвёртку", ubiquity: ubiquity)
        let before = try note.text()
        ubiquity.conflict("Найти отвёртку.md")
        try await note.repository.keep("current", of: note.task)
        #expect(try note.text() == before)
        #expect(!ubiquity.hasConflicts(note.sandbox.url(of: note.task.name)))
    }

    /// Simulates an edit synced from another device: new content and a later modification date.
    private func writeElsewhere(_ text: String, to note: SandboxNote) throws {
        let url = note.sandbox.url(of: note.task.name)
        let seen = try #require(try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        try Data(text.utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.modificationDate: seen.addingTimeInterval(30)], ofItemAtPath: url.path)
    }
}
