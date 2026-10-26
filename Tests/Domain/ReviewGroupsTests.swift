import Foundation
import Testing
@testable import SuperPooper

/// This week's Morning / Day / Evening groups: dragging a task across a header moves it into that group.
struct ReviewGroupsTests {
    private func item(_ name: String, _ part: HabitTimeOfDay? = nil) -> DayItem {
        DayItem(task: makeTask(name) { $0.habit.timeOfDay = part }, state: .open, blockers: [], problems: [])
    }

    private var pool: [DayItem] { [item("Stretch", .morning), item("Pay rent"), item("Call bank"), item("Read", .evening)] }

    @Test func rowsAreGroupedUnderTheirHeaders() {
        #expect(ReviewGroups.rows(pool).map(\.id) == ["header:morning", "Stretch", "header:day", "Pay rent", "Call bank",
                                                     "header:evening", "Read"])
    }

    @Test func aTaskDraggedUnderAnotherHeaderJoinsThatGroup() {
        let rows = ReviewGroups.rows(pool)
        // "Call bank" (index 4) dragged to the top of Morning (before "Stretch").
        let toMorning = ReviewGroups.move(rows, from: [4], to: 1, pool: pool)
        #expect(toMorning.order == ["Call bank", "Stretch", "Pay rent", "Read"])
        #expect(toMorning.regrouped == ["Call bank": .morning])
        // "Stretch" (index 1) dragged to the end, under Evening.
        let toEvening = ReviewGroups.move(rows, from: [1], to: rows.count, pool: pool)
        #expect(toEvening.regrouped == ["Stretch": .evening])
        #expect(toEvening.order.last == "Stretch")
    }

    /// Each group is one plate: its first row has the rounded top, its last row the rounded bottom.
    @Test func eachGroupOpensAndClosesItsPlate() {
        let rows = ReviewGroups.rows(pool)
        let positions = rows.indices.filter { if case .item = rows[$0] { true } else { false } }
            .map { ReviewGroups.position(of: $0, in: rows) }
        #expect(positions.map(\.isFirst) == [true, true, false, true])
        #expect(positions.map(\.isLast) == [true, false, true, true])
    }

    @Test func nothingGoesAboveTheFirstHeader() {
        let rows = ReviewGroups.rows(pool)
        #expect(ReviewGroups.move(rows, from: [3], to: 0, pool: pool).regrouped == ["Pay rent": .morning])
    }

    /// Tasks with a part of the day sort with it but stand on their own plates, not in a habit routine's.
    @Test func morningTasksStandOnTheirOwnPlates() {
        let habit = DayItem(task: makeHabit("Water", status: .habit) { $0.habit.timeOfDay = .morning }, state: .open, blockers: [], problems: [])
        let segments = PoolSegments.make([habit, item("Stretch", .morning), item("Make coffee", .morning)])
        #expect(segments.map { $0.items.map(\.id) } == [["Water"], ["Stretch"], ["Make coffee"]])
        let plan = DayScenario(tasks: [makeTask("Pay rent"), makeTask("Stretch") { $0.habit.timeOfDay = .morning }]).build()
        #expect(plan.poolNames == ["Stretch", "Pay rent"])
    }
}
