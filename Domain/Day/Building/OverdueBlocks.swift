import Foundation

/// Open timed blocks of today whose time has come ride on the "now" cursor, as chain tasks do (`ChainLayout`): tasks,
/// repeatable tasks and habits alike (a habit's block at the time today has, after today's drags). They stack one after
/// another from now in the order of those times and slide along during the day until marked. Nothing is written: the
/// note keeps its time.
struct OverdueBlocks: Sendable {
    /// One block of an item: its id and the time its note has.
    struct Key: Hashable, Sendable {
        let itemID: String
        let written: LocalTime

        init(_ item: DayItem, _ block: BlockTime) {
            itemID = item.id
            written = block.written
        }
    }

    let rules: DayRules
    let times: DayTimes

    /// Where each overdue block starts now.
    func starts(of timed: [DayItem]) -> [Key: Date] {
        let now = times.context.now
        let overdue = timed.flatMap { item in
            times.openTimes(of: item).compactMap { block -> (item: DayItem, block: BlockTime, start: Date)? in
                let start = times.moment(of: block)
                return start < now ? (item, block, start) : nil
            }
        }
        .sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            if lhs.item.id != rhs.item.id { return NameOrder.precedes(lhs.item.id, rhs.item.id) }
            return lhs.block.written < rhs.block.written
        }

        var cursor = now
        var starts: [Key: Date] = [:]
        for (item, block, _) in overdue {
            starts[Key(item, block)] = cursor
            cursor = cursor.addingTimeInterval(rules.duration(of: item.task))
        }
        return starts
    }
}
