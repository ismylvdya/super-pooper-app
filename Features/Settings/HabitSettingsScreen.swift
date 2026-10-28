import SwiftUI

/// Settings of the habits side: whether new habits show in Today, the habit colors, and how the parts of
/// the day are split for sorting (read-only, from rules).
struct HabitSettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.rules) private var rules
    @Environment(\.tokens) private var tokens

    var body: some View {
        PageScaffold(title: L10n.string("settings.habits")) {
            PlateSection(header: "settings.habits.new", hint: "settings.habits.new.hint") {
                PlateRow(icon: .today, title: "habitPage.showInToday", info: "info.habitPage.showInToday") {
                    Toggle("habitPage.showInToday", isOn: Binding(
                        get: { model.settings.habits.showNewHabitsInToday },
                        set: { value in model.updateSettings { $0.habits.showNewHabitsInToday = value } }
                    ))
                    .labelsHidden()
                }
            }
            PlateSection(header: "settings.habits.colors", hint: "settings.habits.colors.hint") {
                ForEach([ColorToken.habit, .twice, .missed], id: \.self) { token in
                    PlateRow(icon: nil, title: LocalizedStringKey(String("color.") + token.rawValue)) { ColorField(token: token) }
                }
            }
            NotificationImageSection()
            PlateSection(header: "settings.habits.partsOfDay", info: "info.settings.habits.partsOfDay") {
                PlateRow(icon: .timeOfDay, title: "habitPage.timeOfDay.morning") {
                    Text(L10n.format("settings.habits.until", rules.day.morningEnds.string)).foregroundStyle(tokens.color(.secondaryText))
                }
                PlateRow(icon: nil, title: "habitPage.timeOfDay.evening") {
                    Text(L10n.format("settings.habits.from", rules.day.eveningStarts.string)).foregroundStyle(tokens.color(.secondaryText))
                }
            }
        }
    }
}
