import Foundation

/// Open timed tasks of today whose time has come ride on the "now" cursor, as chain tasks do (`ChainLayout`): they stack
/// one after another from now in the order of their own times and slide along during the day until they are done. Only
/// tasks; habits keep their slots. Nothing is written: the note keeps its time.
struct OverdueTasks: Sendable {
    let rules: DayRules
    let times: DayTimes

    /// Where each overdue task's block starts now, by item id.
    func starts(of timed: [DayItem]) -> [String: Date] {
        let now = times.context.now
        let overdue = timed.compactMap { item -> (item: DayItem, start: Date)? in
            guard !item.isHabit, let block = times.openTimes(of: item).first else { return nil }
            let start = times.moment(of: block)
            return start < now ? (item, start) : nil
        }
        .sorted { $0.start != $1.start ? $0.start < $1.start : NameOrder.precedes($0.item.id, $1.item.id) }

        var cursor = now
        var starts: [String: Date] = [:]
        for (item, _) in overdue {
            starts[item.id] = cursor
            cursor = cursor.addingTimeInterval(rules.duration(of: item.task))
        }
        return starts
    }
}
