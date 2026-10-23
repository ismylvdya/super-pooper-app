#if DEBUG
import SwiftUI

/// DEBUG only: renders the widget views at their system sizes from the real App Group snapshot,
/// the same data path the widget extension uses.
struct WidgetGalleryScreen: View {
    @Environment(\.tokens) private var tokens
    @State private var source = WidgetDataSource.load()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let source {
                    let now = AppContainer.sharedClockNow
                    widget(width: 338, height: 354) {
                        TodayWidgetView(plan: source.plan(at: now), settings: source.settings, layout: source.config.todayLayout(for: source.settings.today.arrangement),
                                        context: source.context(at: now), maxTimelineHours: source.config.rules.widgets.timelineHours)
                    }
                    if let habit = source.habit(named: "Медитация 🧘") {
                        HStack(spacing: 20) {
                            widget(width: 158, height: 158) {
                                HabitGridView(title: habit.name, grid: HabitGrid(task: habit, weekCount: source.config.rules.widgets.habitGridWeeksSmall,
                                                                                 today: source.context(at: now).today, calendar: source.calendar))
                            }
                        }
                        widget(width: 338, height: 158) {
                            HabitGridView(title: habit.name, grid: HabitGrid(task: habit, weekCount: source.config.rules.widgets.habitGridWeeksMedium,
                                                                             today: source.context(at: now).today, calendar: source.calendar))
                        }
                    }
                } else {
                    Text("No widget data")
                }
            }
            .padding()
        }
        .background(Color(white: 0.85))
        .navigationTitle("Widgets")
    }

    private func widget<Content: View>(width: CGFloat, height: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: width, height: height)
            .background(tokens.color(width > 300 && height > 300 ? .screenBackground : .plateBackground))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
#endif
