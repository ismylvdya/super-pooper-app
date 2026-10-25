import AppIntents

/// Settings of one habit widget, as in the old Habits app: the habit, the title size, wrapping and
/// breaking the title, and how many weeks are shown.
struct SelectHabitIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widget.habit.configure"
    static let description = IntentDescription("widget.habit.description")

    @Parameter(title: "widget.habit.parameter")
    var habit: HabitEntity?

    @Parameter(title: "widget.habit.titleSize", default: .standard)
    var titleSize: HabitWidgetTitleSize

    @Parameter(title: "widget.habit.wrapTitle", description: "widget.habit.wrapTitle.hint", default: false)
    var wrapTitle: Bool

    @Parameter(title: "widget.habit.breakWords", description: "widget.habit.breakWords.hint", default: false)
    var breakWords: Bool

    @Parameter(title: "widget.habit.weeks", default: 4, inclusiveRange: (1, 8))
    var weeks: Int

    init() {}

    init(habit: HabitEntity?) { self.habit = habit }
}

/// What the widget view needs from its settings.
struct HabitWidgetOptions: Sendable {
    var titleSize: Double?
    var wrapTitle = false
    var breakWords = false
    var weeks = 4
}
