import SwiftUI

/// One segment of the pool (`PoolSegments`): a task on its own plate, or the habits of one routine on one shared plate.
/// The app's pool and the Today widget draw their rows with it; `row` puts a row on the plate it is given
/// (`poolRowPlate`), so a row that lifts (the app's long press) lifts with its plate.
struct PoolSegmentView<Row: View>: View {
    let segment: PoolSegments.Segment
    @ViewBuilder let row: (DayItem, PoolRowPlate) -> Row

    var body: some View {
        if segment.isRoutine {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(segment.items) { item in row(item, .piece) }
            }
            .plate(.row, clipsContent: true)
        } else if let item = segment.items.first {
            row(item, .own)
        }
    }
}
