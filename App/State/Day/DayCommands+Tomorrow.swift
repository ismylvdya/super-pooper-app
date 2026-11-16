import Foundation

/// The morning review's Tomorrow: what today's review plans for the next day. A task is kept out of tomorrow's pool by its
/// line (`#not_tomorrow`, the day's turn reads it); a habit, the order and having reviewed it by tomorrow's plan
/// (`DayState.Ahead`), which becomes tomorrow's state once it comes.
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

    /// A drag in the review's Tomorrow: tomorrow's order, and a new part of the day for the tasks that changed group.
    func applyTomorrowMove(_ move: ReviewGroups.Move) {
        day.planTomorrow { $0.manualOrder = move.order }
        for (name, group) in move.regrouped {
            writer.enqueueEdit(name) { _ in [.timeOfDay(group.timeOfDay)] }
        }
        Task { await derived.publish() }
    }

    func resetTomorrowOrder() {
        day.planTomorrow { $0.manualOrder = nil }
        Task { await derived.publish() }
    }

    /// Tomorrow was reviewed today: its review does not open by itself that morning.
    func markTomorrowReviewed() {
        guard !day.tomorrow.reviewed else { return }
        day.planTomorrow { $0.reviewed = true }
    }
}
