import SwiftUI
import Testing
@testable import SuperPooperApp

/// While a task is dragged on the timeline only the minutes (":30") stand in the hour column; no line runs across.
@MainActor
struct TimelineDropMarkerTests {
    @Test func theMarkerIsOnlyTheMinutesInTheHourColumn() throws {
        let labelWidth: CGFloat = 40
        let marker = TimelineDropMarker(moment: TestCalendar.date(TestCalendar.wednesday, "10:30"), labelWidth: labelWidth, width: 300)
            .frame(width: 300, height: 40)
            .environment(\.calendar, TestCalendar.calendar)
            .environment(\.colorScheme, .light)
        let columns = try RenderedAlpha(marker).inkedColumns()
        #expect(!columns.isEmpty)
        #expect(columns.allSatisfy { $0 < Int(labelWidth) })
    }
}
