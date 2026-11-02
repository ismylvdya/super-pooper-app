import Testing
@testable import SuperPooperApp

/// A repeatable task's page has neither the history grid nor the statistics (.26977), unless the habits settings ask for
/// both (.27056); a habit's page always has them.
struct RepeatableHistorySettingTests {
    private let habit = makeHabit("Push-ups")
    private let repeatable = makeHabit("Pay rent") { $0.habit.repeatable = true }

    @Test func byDefaultOnlyAHabitShowsItsHistory() {
        let settings = TestConfig.defaults.habits
        #expect(!settings.repeatableShowsHistory)
        #expect(settings.showsHistory(of: habit))
        #expect(!settings.showsHistory(of: repeatable))
    }

    @Test func theSettingShowsARepeatableTasksHistoryToo() {
        var settings = TestConfig.defaults.habits
        settings.repeatableShowsHistory = true
        #expect(settings.showsHistory(of: habit))
        #expect(settings.showsHistory(of: repeatable))
    }
}
