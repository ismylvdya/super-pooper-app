import SwiftUI

/// Monday … Sunday initials above a habit grid, one per cell.
struct WeekdayHeader: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.calendar) private var calendar
    let metrics: HabitDotMetrics

    var body: some View {
        HStack(spacing: metrics.spacing) {
            ForEach(Weekday.allCases, id: \.self) { day in
                Text(verbatim: day.name(.initial, in: calendar))
                    .secondaryText()
                    .frame(width: metrics.cell)
            }
        }
    }
}
