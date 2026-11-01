import Foundation
import Testing
@testable import SuperPooperApp

/// A note is a task, a habit or a repeatable task, and the delete confirmation names which (.472).
struct NoteKindTests {
    @Test func aNoteKnowsItsKind() {
        #expect(makeTask("Report").kind == .task)
        #expect(makeHabit("Stretch").kind == .habit)
        #expect(makeHabit("Vacuum") { $0.habit.repeatable = true }.kind == .repeatable)
    }

    @Test func theDeleteConfirmationNamesTheKind() throws {
        let delete = TestConfig.actions.definition(.delete)
        let titles = NoteKind.allCases.map { delete.confirmTitle(for: $0).map(L10n.string) }
        #expect(titles == ["Delete task?", "Delete habit?", "Delete repeatable task?"])
    }
}
