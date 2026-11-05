import Foundation

/// What the search in Settings finds: every section of the settings pages with the titles of its rows, and the page it
/// stands on (nil: Settings itself). A section is found by its own title or by a row's; it shows the rows that match,
/// or all of them when only its title does.
enum SettingsSearchIndex {
    struct Section: Hashable {
        let title: String
        let route: Route?
        let rows: [String]
    }

    /// A section found, its matching rows already localized.
    struct Result: Hashable {
        let title: String
        let route: Route?
        let rows: [String]
    }

    static let sections: [Section] = [
        Section(title: "settings.tabBar", route: .tabBarSettings, rows: ["settings.tabBar.summary", "newItem.title"]),
        Section(title: "settings.clock", route: .clockSettings, rows: ["settings.clock.prefix", "settings.clock.zone"]),
        Section(title: "settings.sources", route: .generalSettings,
                rows: ["settings.vault", "settings.access.calendar", "settings.access.reminders", "settings.access.notifications",
                       "settings.calendars", "settings.reminderLists"]),
        Section(title: "settings.day", route: .generalSettings, rows: ["settings.day.boundary", "settings.day.energyHour"]),
        Section(title: "settings.today", route: .taskSettings, rows: ["settings.today.arrangement", "settings.landscape"]),
        Section(title: "settings.timeline", route: .taskSettings,
                rows: ["settings.timeline.layout", "settings.timeline.range", "settings.timeline.hoursBefore",
                       "settings.timeline.hoursAfter", "settings.timeline.firstHalf", "settings.timeline.secondHalf",
                       "settings.timeline.taskFont", "settings.timeline.bellSize",
                       "settings.timeline.bellOpacity", "settings.timeline.showEvents", "settings.timeline.showReminders",
                       "settings.timeline.showTasks", "settings.timeline.showHabits"]),
        Section(title: "settings.pool", route: .taskSettings, rows: ["settings.pool.selectionOutline", "settings.pool.visible", "settings.pool.highPriority"]),
        Section(title: "settings.lists", route: .generalSettings, rows: ["settings.listsIcon"]),
        Section(title: "settings.appearance", route: .taskSettings, rows: ["settings.pastOpacity"]),
        Section(title: "settings.colors", route: .taskSettings, rows: []),
        Section(title: "settings.widgets", route: .widgetSettings, rows: ["settings.widget"]),
        Section(title: "settings.widgetColors", route: .widgetSettings, rows: []),
        Section(title: "settings.notifications", route: .notificationSettings, rows: ["settings.notifications.enabled", "settings.notifications.snooze", "settings.notifications.alarmSound", "settings.notifications.signing"]),
        Section(title: "routines.title", route: .routines, rows: []),
        Section(title: "settings.tasks", route: .plainTaskSettings, rows: ["settings.pool.startedFill", "settings.pool.startedColor"]),
        Section(title: "settings.habits.new", route: .habitSettings, rows: ["habitPage.showInToday", "habitPage.color"]),
        Section(title: "settings.habits.repeatable", route: .habitSettings, rows: ["settings.habits.repeatableHistory"]),
        Section(title: "settings.habits.colors", route: .habitSettings, rows: []),
        Section(title: "settings.habits.marks", route: .habitSettings, rows: ["settings.habits.ringOpacity"]),
        Section(title: "settings.notificationImage", route: .habitSettings,
                rows: ["settings.notificationImage.show", "settings.notificationImage.picture", "settings.notificationImage.habitColor"]),
    ]

    /// The sections `query` finds, in the order the pages show them; none for an empty query.
    static func results(_ query: String, localize: (String) -> String = L10n.string) -> [Result] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return sections.compactMap { section in
            let title = localize(section.title)
            let rows = section.rows.map(localize)
            let matching = rows.filter { SearchMatcher.matches($0, query) }
            if !matching.isEmpty { return Result(title: title, route: section.route, rows: matching) }
            return SearchMatcher.matches(title, query) ? Result(title: title, route: section.route, rows: rows) : nil
        }
    }
}
