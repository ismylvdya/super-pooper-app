import Foundation

/// The morning review's Tomorrow: what today's review plans for the next day. A task is kept out of tomorrow's pool by its
/// line (`#not_tomorrow`, the day's turn reads it); a habit and having reviewed it by tomorrow's plan
/// (`DayState.Ahead`), which becomes tomorrow's state once it comes. Its order is the order of the lines, as today's is.
extension DayCommands {
    func notTomorrow(_ name: String) async {
        guard let task = tasks.task(named: name) else { return }
        if task.isHabit {
            day.planTomorrow { if !$0.skipped.containsNoteName(name) { $0.skipped.append(name) } }
            await derived.publish()
        } else {
            await writer.edit(name) { _ in [.notTomorrow(true)] }
        }
    }

    func returnTomorrow(_ name: String) async {
        guard let task = tasks.task(named: name) else { return }
        if task.isHabit {
            day.planTomorrow { $0.skipped.removeAll { $0.isSameNoteName(as: name) } }
            await derived.publish()
        } else {
            await writer.edit(name) { _ in [.notTomorrow(false)] }
        }
    }


    /// Tomorrow was reviewed today: its review does not open by itself that morning.
    func markTomorrowReviewed() {
        guard !day.tomorrow.reviewed else { return }
        day.planTomorrow { $0.reviewed = true }
    }
}
