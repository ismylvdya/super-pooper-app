import Foundation

/// The pool order while a task is dragged over it: the task goes in front of the first row whose middle is below the
/// finger, into the section whose header is above the finger.
enum PoolDropOrder {
    struct Row: Equatable {
        let id: String
        let midY: Double
        var section: String?
    }

    static func order(rows: [Row], dragged: String, at y: Double) -> [String] {
        let others = rows.filter { $0.id != dragged }.sorted { $0.midY < $1.midY }
        let index = others.firstIndex { $0.midY > y } ?? others.count
        var ids = others.map(\.id)
        ids.insert(dragged, at: index)
        return ids
    }

    /// The order the drop makes and the section it lands in (nil: a pool without section headers).
    static func drop(rows: [Row], headers: [SectionDropOrder.Header], dragged: String,
                     at y: Double) -> (order: [String], section: String?) {
        (order(rows: rows, dragged: dragged, at: y), SectionDropOrder.section(headers: headers, at: y))
    }

    /// A worm dragged whole: its other members follow the grabbed one, in their order.
    static func keepingTogether(_ order: [String], dragged: String, along: [String]) -> [String] {
        let followers = along.filter { $0 != dragged && order.contains($0) }
        var ids = order.filter { !followers.contains($0) }
        let spot = (ids.firstIndex(of: dragged) ?? ids.count - 1) + 1
        ids.insert(contentsOf: followers, at: min(spot, ids.count))
        return ids
    }
}
