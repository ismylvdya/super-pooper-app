import AppIntents

/// The day button of the habit widget: cycles today's mark like a tap in the Habits tab.
/// As a `LiveActivityIntent` it runs in the app's process (the widget cannot open the vault);
/// the app writes the note and reloads the widgets.
struct MarkHabitTodayIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "widget.habit.mark"
    static let isDiscoverable = false

    @Parameter(title: "widget.habit.parameter")
    var habitName: String

    init() {}

    init(habitName: String) { self.habitName = habitName }

    func perform() async throws -> some IntentResult {
        await AppActionBridge.tapHabit(habitName)
        return .result()
    }
}
