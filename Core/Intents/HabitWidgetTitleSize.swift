import AppIntents

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
