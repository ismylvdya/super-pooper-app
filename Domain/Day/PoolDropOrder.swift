import Foundation

/// The pool order while a task is dragged over it: the task goes in front of the first row whose
/// middle is below the finger.
enum PoolDropOrder {
    struct Row: Equatable {
        let id: String
        let midY: Double
    }

    static func order(rows: [Row], dragged: String, at y: Double) -> [String] {
        let others = rows.filter { $0.id != dragged }.sorted { $0.midY < $1.midY }
        let index = others.firstIndex { $0.midY > y } ?? others.count
        var ids = others.map(\.id)
        ids.insert(dragged, at: index)
        return ids
    }
}
