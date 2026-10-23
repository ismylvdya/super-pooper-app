import Foundation
import Testing
@testable import SuperPooper

/// The habit keys in a note (`habit_color`, `harmful`, `show_in_today`, …): written readable for Obsidian,
/// read back the same, removed when switched off.
@Suite("Habit notes")
struct HabitNoteTests {
    @Test func habitOptionsRoundTrip() async throws {
        let note = try await SandboxNote("Медитация 🧘")
        let written = try await note.apply([.habitColor("#34C759"), .harmful(true), .showInToday(false), .timeOfDay(.evening),
                                            .twiceADay(true), .twiceCountsDouble(true), .weeklyGoal(4)]).task
        let text = try note.text()
        for line in ["habit_color: \"#34C759\"", "harmful: true", "show_in_today: false", "time_of_day: evening",
                     "twice_a_day: true", "twice_counts_double: true", "weekly_goal: 4"] {
            #expect(text.contains(line))
        }
        #expect(written.habit.color == "#34C759" && written.habit.harmful && !written.habit.showInToday)
        #expect(written.habit.timeOfDay == .evening && written.habit.skipRule == .weeklyGoal(times: 4))
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
        #expect(try note.text().contains("show_in_today: true"))
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
