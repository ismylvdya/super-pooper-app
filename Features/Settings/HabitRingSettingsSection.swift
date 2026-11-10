import SwiftUI

/// How faded the ring of a habit's day not done or done partly is, with the four marks drawn as everywhere else.
struct HabitRingSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    var body: some View {
        PlateSection(header: "settings.habits.marks", info: "info.settings.habits.ringOpacity") {
            ShareSlider(icon: .opacity, title: "settings.habits.ringOpacity", value: \.habits.ringOpacity,
                        limits: model.config.rules.limits.ringOpacity, accessibilityID: "settings.habits.ringOpacity")
            preview
        }
    }

    /// A day of each look, in the habits' color, as the Habits list draws today's.
    private var preview: some View {
        let metrics = HabitDotMetrics(dot: tokens.size(.iconColumn), ringRatio: tokens.ratio(.habitRing))
        return HStack(spacing: tokens.space(.iconTextGap)) {
            ForEach([HabitCell.open, .partial, .done, .twice], id: \.self) { cell in
                HabitDayCell(cell: cell, color: tokens.color(.habit), metrics: metrics)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
}
