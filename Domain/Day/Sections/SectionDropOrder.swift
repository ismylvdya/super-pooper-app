import Foundation

/// Where a section dragged by its header lands among the pool's sections, and which section a spot in the pool is in.
enum SectionDropOrder {
    struct Header: Equatable, Sendable {
        let id: String
        let midY: Double
    }

    /// Below another header's middle the dragged section goes after that whole section, above it before it.
    static func order(headers: [Header], dragged: String, at y: Double) -> [String] {
        var ids = headers.filter { $0.id != dragged }.sorted { $0.midY < $1.midY }.map(\.id)
        let index = headers.filter { $0.id != dragged && $0.midY < y }.count
        ids.insert(dragged, at: index)
        return ids
    }

    /// The section under the last header above `y` (the first one above them all); nil without headers.
    static func section(headers: [Header], at y: Double) -> String? {
        let sorted = headers.sorted { $0.midY < $1.midY }
        return (sorted.last { $0.midY < y } ?? sorted.first)?.id
    }
}
