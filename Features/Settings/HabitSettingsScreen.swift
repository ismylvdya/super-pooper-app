import SwiftUI

/// Settings of the habits side: whether new habits show in Today, the habit colors, rings and notification pictures.
struct HabitSettingsScreen: View {
    @Environment(AppModel.self) private var model
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
                PlateRow(icon: .colors, title: "habitPage.color") { newHabitColor }
            }
            PlateSection(header: "settings.habits.repeatable", hint: "settings.habits.repeatable.hint") {
                PlateRow(icon: .recurrence, title: "settings.habits.repeatableHistory") {
                    Toggle("settings.habits.repeatableHistory", isOn: Binding(
                        get: { model.settings.habits.repeatableShowsHistory },
                        set: { value in model.updateSettings { $0.habits.repeatableShowsHistory = value } }
                    ))
                    .labelsHidden()
                    .accessibilityIdentifier("settings.habits.repeatableHistory")
                }
            }
            PlateSection(header: "settings.habits.colors", hint: "settings.habits.colors.hint") {
                ForEach(tokens.editableColors[.habits], id: \.self) { token in
                    PlateRow(icon: nil, title: LocalizedStringKey(String("color.") + token.rawValue)) { ColorField(token: token) }
                }
            }
            HabitRingSettingsSection()
            NotificationImageSection()
        }
    }
}

extension HabitSettingsScreen {
    /// The color a new habit gets; its reset brings back the bundled one (black).
    private var newHabitColor: some View {
        let bundled = model.config.defaultSettings.values.habits.newHabitColor
        let current = model.settings.habits.newHabitColor
        return HexColorField(color: UIColor(hex: current).map(Color.init(uiColor:)) ?? tokens.color(.primaryText),
                             stored: current == bundled ? nil : current, accessibilityID: "settings.habits.newColor") { value in
            model.updateSettings { $0.habits.newHabitColor = value ?? bundled }
        }
    }
}
