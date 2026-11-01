import Foundation

struct TimelineSlot: Identifiable, Hashable, Sendable {
    let content: TimelineContent
    let start: Date
    let end: Date
    /// Finished events are drawn greyed out (done tasks and reminders leave the timeline).
    let isPast: Bool
    /// Which of a habit's several times of day this block is (it keeps the ids of the blocks apart): the time its note
    /// has, also for a block dragged to another time today. A timed task's own time.
    var time: LocalTime? = nil
    /// An event with a Calendar alert shows the bell. Every timed task and habit on today's timeline rings at its time
    /// and a reminder rings at its own, so the bell would tell nothing about them.
    var showsBell: Bool {
        if case .event(let event) = content { return event.hasAlarm }
        return false
    }

    var id: String {
        content.id + (time.map { "@\($0.string)" } ?? "")
    }
}
