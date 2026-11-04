import SwiftUI

/// One segment of the pool (`PoolSegments`): a task on its own plate, or a worm or the habits of one routine on one shared plate.
/// The app's pool and the Today widget draw their rows with it; `row` puts a row on the plate it is given
/// (`poolRowPlate`), so a row that lifts (the app's long press) lifts with its plate.
struct PoolSegmentView<Row: View>: View {
    let segment: PoolSegments.Segment
    @ViewBuilder let row: (DayItem, PoolRowPlate) -> Row
    /// How tall the rows of a shared plate are.
    @State private var rowHeights: [String: CGFloat] = [:]

    var body: some View {
        if segment.isShared {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(segment.items) { item in
                    row(item, .piece)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeights[item.id] = $0 }
                }
            }
            // A row's plate rounds by at most half its height: the shared one rounds no more, or it would cut a row's
            // outline at its corners.
            .plate(.row, clipsContent: true, maxRadius: (rowHeights.values.min() ?? .infinity) / 2)
        } else if let item = segment.items.first {
            row(item, .own)
        }
    }
}
