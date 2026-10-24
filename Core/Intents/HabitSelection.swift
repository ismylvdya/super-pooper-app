import AppIntents

/// A recurring task offered in the Habit grid widget configuration (read from the widget snapshot).
struct HabitEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "widget.habit.entity")
    static let defaultQuery = HabitQuery()

    let id: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
}

struct HabitQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [HabitEntity] {
        identifiers.map(HabitEntity.init(id:))
    }

    func suggestedEntities() async throws -> [HabitEntity] {
        WidgetDataSource.load()?.habitNames.map(HabitEntity.init(id:)) ?? []
    }
}

/// Title sizes offered in the habit widget settings; Default = the widget title token.
enum HabitWidgetTitleSize: Int, AppEnum {
    case standard = 0, s14 = 14, s16 = 16, s18 = 18, s20 = 20, s22 = 22, s24 = 24, s26 = 26, s28 = 28, s32 = 32

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "widget.habit.titleSize")
    static let caseDisplayRepresentations: [HabitWidgetTitleSize: DisplayRepresentation] = [
        .standard: "widget.habit.titleSize.default", .s14: "14", .s16: "16", .s18: "18", .s20: "20", .s22: "22",
        .s24: "24", .s26: "26", .s28: "28", .s32: "32",
    ]

    /// nil = the default size.
    var points: Double? { self == .standard ? nil : Double(rawValue) }
}

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
