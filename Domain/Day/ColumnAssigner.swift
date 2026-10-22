import Foundation

/// Side-by-side placement of overlapping blocks, like Calendar's day view:
/// each cluster of overlapping intervals is split into equal columns.
enum ColumnAssigner {
    struct Placement: Hashable, Sendable {
        let column: Int
        let columnCount: Int
    }

    /// `intervals` are (start, end) in any comparable unit; the result keeps the input order.
    static func assign(_ intervals: [(start: Double, end: Double)]) -> [Placement] {
        let order = intervals.indices.sorted {
            intervals[$0].start != intervals[$1].start
                ? intervals[$0].start < intervals[$1].start
                : intervals[$0].end > intervals[$1].end
        }
        var placements = [Placement?](repeating: nil, count: intervals.count)
        var cluster: [Int] = []
        var columnEnds: [Double] = []
        var columnOf: [Int: Int] = [:]
        var clusterEnd = -Double.infinity

        func closeCluster() {
            for index in cluster {
                placements[index] = Placement(column: columnOf[index] ?? 0, columnCount: max(columnEnds.count, 1))
            }
            cluster.removeAll()
            columnEnds.removeAll()
        }

        for index in order {
            let interval = intervals[index]
            if interval.start >= clusterEnd { closeCluster() }
            if let free = columnEnds.firstIndex(where: { $0 <= interval.start }) {
                columnEnds[free] = interval.end
                columnOf[index] = free
            } else {
                columnEnds.append(interval.end)
                columnOf[index] = columnEnds.count - 1
            }
            cluster.append(index)
            clusterEnd = max(clusterEnd, interval.end)
        }
        closeCluster()
        return placements.map { $0 ?? Placement(column: 0, columnCount: 1) }
    }
}
