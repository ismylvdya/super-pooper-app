import Testing
@testable import SuperPooperApp

/// A mark action's image is the image of the mark it sets: one mapping from actions to marks (`ActionID.habitMark`).
struct HabitMarkIconTests {
    @Test func aMarkActionShowsTheMarkItSets() {
        #expect(HabitMarkIcon.icon(for: ActionID.done) == .habitMarkDone)
        #expect(HabitMarkIcon.icon(for: ActionID.partial) == .habitMarkPartial)
        #expect(HabitMarkIcon.icon(for: ActionID.twice) == .habitMarkTwice)
        #expect(HabitMarkIcon.icon(for: ActionID.unmark) == .habitMarkOpen)
        #expect(HabitMarkIcon.icon(for: ActionID.archive) == nil)
        #expect(ActionID.allCases.filter(\.setsHabitMark) == [.done, .partial, .twice, .unmark])
    }
}
