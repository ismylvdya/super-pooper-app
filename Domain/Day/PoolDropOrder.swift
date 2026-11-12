import Foundation

/// The pool order while a task is dragged over it: the task goes in front of the first row whose middle is below the
/// finger, into the section whose header is above the finger. In a long pool only the rows on screen say where they
/// stand (a row scrolled away keeps where it last was, or was never measured): `all`, the pool's own order, keeps the
/// others in their places around the dragged one.
enum PoolDropOrder {
    struct Row: Equatable {
        let id: String
        let midY: Double
        var section: String?
    }

    static func order(rows: [Row], all: [String]? = nil, dragged: String, at y: Double) -> [String] {
        let measured = rows.filter { $0.id != dragged }.sorted { $0.midY < $1.midY }
        var ids = (all ?? measured.map(\.id)).filter { $0 != dragged }
        if let below = measured.first(where: { $0.midY > y }), let index = ids.firstIndex(of: below.id) {
            ids.insert(dragged, at: index)
        } else if let last = measured.last, let index = ids.firstIndex(of: last.id) {
            ids.insert(dragged, at: index + 1)
        } else {
            ids.append(dragged)
        }
        return ids
    }

    /// The order the drop makes and the section it lands in (nil: a pool without section headers).
    /// `inSections`: the pool has section headers, though maybe none on screen.
    static func drop(rows: [Row], all: [String]? = nil, headers: [SectionDropOrder.Header], inSections: Bool? = nil,
                     dragged: String, at y: Double) -> (order: [String], section: String?) {
        let order = order(rows: rows, all: all, dragged: dragged, at: y)
        guard inSections ?? !headers.isEmpty else { return (order, nil) }
        // A header scrolled away says nothing: the section is the one of the row on screen above the finger, or below it.
        let measured = rows.filter { $0.id != dragged }.sorted { $0.midY < $1.midY }
        let neighbour = measured.last { $0.midY <= y } ?? measured.first
        return (order, SectionDropOrder.section(headers: headers, at: y) ?? neighbour?.section)
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
