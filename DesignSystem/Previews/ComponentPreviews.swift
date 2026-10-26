#if DEBUG
import SwiftUI

#Preview("Task rows") {
    let plan = PreviewSamples.plan
    return VStack(alignment: .leading, spacing: 12) {
        ForEach(plan.pool) { TaskRowView(item: $0, today: plan.today, onOpen: {}) }
    }
    .padding()
}

#Preview("Marks") {
    HStack {
        MarkGlyph(state: .open, color: .purple)
        MarkGlyph(state: .marked(.done), color: .purple)
        MarkGlyph(state: .marked(.partial), color: .purple)
        MarkGlyph(state: .marked(.twice), color: .purple)
    }
}

#Preview("Plate section") {
    ScrollView {
        PlateSection(header: "settings.day", info: "info.settings.day.boundary", hint: "settings.day.hint") {
            PlateRow(icon: .dayBoundary, title: "settings.day.boundary", info: "info.settings.day.boundary") { Text(verbatim: "04:00") }
            PlateRow(icon: .energyHour, title: "settings.day.energyHour") { Toggle("", isOn: .constant(true)).labelsHidden() }
            PlateRow(icon: nil, title: "taskPage.due.time", indent: true) { Text(verbatim: "09:00") }
        }
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Chips") {
    HStack {
        Chip(icon: .high, tint: .red)
        Chip(icon: .due, text: "Fri")
        Chip(text: "15 min")
        Chip(icon: .energy, isOn: false)
    }
}

#Preview("Banner") {
    BannerView(text: "Task Купить батарейки was changed in two places, the latest version was kept",
               icon: .problem, tint: .orange) {}
}

#Preview("Timeline") {
    let plan = PreviewSamples.plan
    let context = PreviewSamples.context
    return ScrollView {
        DayTimelineView(slots: plan.timeline,
                        window: TimelineWindow.rolling(now: plan.now, hoursBefore: 2, hoursAfter: 9, calendar: context.calendar),
                        now: plan.now, hourHeight: 64,
                        style: TimelineStyle(eventFont: .subheadline, taskFont: .subheadline,
                                             eventLineHeight: UIFont.preferredFont(forTextStyle: .subheadline).lineHeight,
                                             taskLineHeight: UIFont.preferredFont(forTextStyle: .subheadline).lineHeight,
                                             minimumItemHeight: 34)) { item, _ in
            TaskRowView(item: item, today: plan.today, showsDetails: false)
        }
        .padding()
    }
}

#Preview("Habit grid") {
    let context = PreviewSamples.context
    let habit = PreviewSamples.tasks[0]
    return HabitWidgetView(habit: habit, grid: HabitGrid(task: habit, weekCount: 4, today: context.today, days: context.days),
                           today: context.today)
        .frame(width: 158, height: 158)
}

#Preview("Today widget") {
    TodayWidgetView(plan: PreviewSamples.plan, settings: .fallback,
                    layout: ScreenLayout(axis: .vertical, spacing: "blockGap",
                                         blocks: [.init(block: .pool, size: .fit, weight: nil), .init(block: .timeline, size: .fill, weight: 1)]),
                    context: PreviewSamples.context, maxTimelineHours: 6)
        .frame(width: 338, height: 354)
}
#endif
