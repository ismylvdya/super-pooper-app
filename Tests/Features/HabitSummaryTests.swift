import Foundation
import Testing
@testable import SuperPooperApp

/// Under a habit's name in the Habits list: its routine and Twice as one line of text, as the owner asked (D-058).
@MainActor
struct HabitSummaryTests {
    @Test func theRoutineAndTwiceStandOnOneLine() {
        let habit = makeHabit("Push-ups") { $0.habit.timeOfDay = .morning; $0.habit.twiceADay = true }
        let line = HabitSummary.traitsLine(habit)
        #expect(line?.text == "Morning · Twice")
        #expect(line?.text == L10n.string("habits.trait.morning") + L10n.string("habits.traits.separator") + L10n.string("habits.trait.twice"))
    }

    /// VoiceOver reads a list, not the separator.
    @Test func voiceOverHearsAList() {
        let habit = makeHabit("Push-ups") { $0.habit.timeOfDay = .evening; $0.habit.twiceADay = true }
        #expect(HabitSummary.traitsLine(habit)?.spoken == "Evening, Twice")
    }

    @Test(arguments: [(HabitTimeOfDay.morning, "Morning"), (.day, "Day"), (.evening, "Evening")])
    func eachRoutineHasItsName(part: HabitTimeOfDay, name: String) {
        let habit = makeHabit("Stretch") { $0.habit.timeOfDay = part }
        #expect(HabitSummary.traitsLine(habit) == HabitSummary.TraitsLine(text: name, spoken: name))
    }

    /// Two reminders a day make a habit Twice even without the option.
    @Test func twoRemindersAreTwice() {
        let habit = makeHabit("Water") { $0.reminderTimes = [LocalTime("09:00"), LocalTime("21:00")] }
        #expect(HabitSummary.traitsLine(habit)?.text == "Twice")
    }

    @Test func aHabitWithNeitherHasNoLine() {
        #expect(HabitSummary.traitsLine(makeHabit("Read")) == nil)
    }
}
