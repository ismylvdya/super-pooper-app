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
}
