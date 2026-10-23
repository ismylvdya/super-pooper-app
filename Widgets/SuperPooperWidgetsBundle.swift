import SwiftUI
import WidgetKit

@main
struct SuperPooperWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        HabitGridWidget()
        ClockWidget()
    }
}
