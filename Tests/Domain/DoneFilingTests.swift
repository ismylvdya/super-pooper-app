import Foundation
import Testing
@testable import SuperPooperApp

/// Done tasks move to the done folder at once; habits and open tasks stay.
struct DoneFilingTests {
    @Test func everyDoneTaskIsFiledButNotHabits() {
        let yesterday = makeTask("Yesterday", status: .done) { $0.completedDate = LocalDate("2026-10-20") }
        let undated = makeTask("Undated", status: .done)
        let doneToday = makeTask("Today", status: .done) { $0.completedDate = LocalDate("2026-10-21") }
        let open = makeTask("Open")
        let habit = makeTask("Habit", status: .habit)
        #expect(DoneFiling.due([yesterday, undated, doneToday, open, habit]).map(\.name) == ["Yesterday", "Undated", "Today"])
    }

}
