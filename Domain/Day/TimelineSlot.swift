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
    /// Something will alert at this block: a reminder, an event with a Calendar alert, a timed task or
    /// habit with its notification. The block shows the bell.
    var alerts = false

    var id: String {
        content.id + (time.map { "@\($0.string)" } ?? "")
    }
}
