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

/// Configuration of the Habit grid widget: which recurring task to show.
struct SelectHabitIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widget.habit.configure"
    static let description = IntentDescription("widget.habit.description")

    @Parameter(title: "widget.habit.parameter")
    var habit: HabitEntity?

    init() {}

    init(habit: HabitEntity?) { self.habit = habit }
}
