import Foundation
import Testing
@testable import SuperPooperApp

/// One scanned note of a fresh sandbox and the repository that scanned it; `task` follows every write.
final class SandboxNote {
    let sandbox: VaultSandbox
    let repository: VaultTaskRepository
    private(set) var task: TaskItem

    init(_ name: String, sandbox: VaultSandbox? = nil, ubiquity: UbiquityService = FakeUbiquityService(),
         calendar: CalendarSource = FixedCalendar(current: TestCalendar.calendar)) async throws {
        let sandbox = try sandbox ?? VaultSandbox.make()
        self.sandbox = sandbox
        repository = sandbox.repository(ubiquity: ubiquity, calendar: calendar)
        task = try #require(try await repository.load().tasks.first { $0.name == name })
    }

    func text() throws -> String { try sandbox.text(of: task.name) }

    /// Scans again (after the file was changed behind the repository's back).
    func reload() async throws -> TaskItem {
        let name = task.name
        task = try #require(try await repository.load().tasks.first { $0.name == name })
        return task
    }

    @discardableResult
    func apply(_ changes: [TaskEdit]) async throws -> TaskWriteResult {
        let result = try await repository.apply(changes, to: task)
        task = result.task
        return result
    }

    /// The same changes the app writes for a tap or a menu mark today.
    @discardableResult
    func mark(_ mark: HabitMark?) async throws -> TaskItem {
        try await apply(TaskMarking(today: LocalDate(sandbox.today)).changes(marking: task, as: mark)).task
    }
}

extension String {
    /// Replaces a fragment that must occur exactly once.
    func replacingOnce(_ fragment: String, with replacement: String) throws -> String {
        let count = components(separatedBy: fragment).count - 1
        guard count == 1, let range = range(of: fragment) else {
            throw ReplaceError(fragment: fragment, count: count)
        }
        return replacingCharacters(in: range, with: replacement)
    }

    struct ReplaceError: Error, CustomStringConvertible {
        let fragment: String
        let count: Int
        var description: String { "\"\(fragment)\" occurs \(count) times, expected once" }
    }
}

/// Splits a note into its frontmatter (both delimiters included) and its body.
func splitNote(_ text: String) -> (frontmatter: String, body: String)? {
    guard text.hasPrefix("---\n"),
          let closing = text.range(of: "\n---\n", range: text.index(text.startIndex, offsetBy: 3)..<text.endIndex) else { return nil }
    return (String(text[..<closing.upperBound]), String(text[closing.upperBound...]))
}
