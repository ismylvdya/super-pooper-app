import Foundation
import Testing
@testable import SuperPooperApp

/// One way to show what a search of notes finds: titled groups, empty ones left out, nothing before something is typed.
@Suite("Search sections")
struct SearchSectionsTests {
    private let habits = [makeHabit("Run", status: .habit), makeHabit("Rent", status: .habit) { $0.habit.repeatable = true },
                          makeHabit("Tea", status: .habit)]

    @Test func habitsThenRepeatableTasks() {
        let found = SearchSections.habits(habits, matching: "r")
        #expect(found.map(\.title) == [.key("search.habits"), .key("search.repeatable")])
        #expect(found.map { $0.notes.map(\.name) } == [["Run"], ["Rent"]])
    }

    @Test func nothingBeforeSomethingIsTyped() {
        #expect(SearchSections.habits(habits, matching: "").isEmpty)
        #expect(SearchSections.notes(habits, matching: "").isEmpty)
    }

    @Test func anEmptyGroupIsLeftOut() {
        #expect(SearchSections.habits(habits, matching: "tea").map(\.title) == [.key("search.habits")])
    }
}
