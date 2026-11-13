import Foundation
import Testing
@testable import SuperPooperApp

/// The bundled configs load and are complete; config typos produce readable errors.
struct ConfigTests {
    @Test func bundledConfigsLoad() throws {
        let config = try AppConfig.load(bundle: Bundle(for: BundleToken.self).appHostBundle)
        #expect(config.todayStacked.blocks.map(\.block) == [.pool, .timeline])
        #expect(config.todayStacked.axis == .vertical)
        #expect(config.todaySideBySide.axis == .horizontal)
        #expect(config.sort.pool == PoolSortCriterion.allCases)
        #expect(config.rules.timeEstimates.map(\.minutes) == [2, 15, 60, 240])
    }

    /// Partially and Twice are picked on the Habits page and in the history only; Today and the notifications offer
    /// Done (a twice-a-day habit's second Done is Twice) and Skip today, in red.
    @Test func partialAndTwiceStayOnTheHabitsPage() {
        #expect(TestConfig.actions.menus[.habitDay].actions == [.unmark, .partial, .done, .twice, .skipToday])
        #expect(TestConfig.actions.menus[.habitContext].frequent == [.unmark, .done, .skipToday])
        #expect(TestConfig.actions.menus[.habitNotification].actions == [.done, .skipToday, .snooze])
        #expect(TestConfig.actions.menus[.habitNotification].more == [.snooze], "the rarer actions stand under the frequent ones")
        // Not today: red for a habit or repeatable task, plain for a task; one icon and one title for both.
        #expect(TestConfig.actions.definition(.skipToday).destructive && !TestConfig.actions.definition(.notToday).destructive)
        #expect(TestConfig.actions.definition(.skipToday).icon == TestConfig.actions.definition(.notToday).icon)
        #expect(TestConfig.actions.menus[.eventContext].actions == [.deleteEvent])
    }

    /// Every kind of notification can be snoozed (.2910); the in-app menus cannot, and the snooze lasts an hour.
    @Test func everyNotificationOffersSnooze() {
        let notifications: [ActionMenu] = [.habitNotification, .taskNotification, .reminderNotification, .eventNotification]
        for menu in ActionMenu.allCases {
            #expect(TestConfig.actions.menus[menu].actions.contains(.snooze) == notifications.contains(menu), "\(menu)")
        }
        #expect(!TestConfig.actions.definition(.snooze).destructive)
        #expect(TestConfig.rules.notifications.snoozeChoices.contains(30))
    }

    /// Select mode's bar: Done and Not today or Skip today as buttons, the rest under "…"; the long-press menus offer Unworm, and Select mode starts from the bar's "…" alone.
    @Test func theSelectionMenuNamesKnownActions() {
        let selection = TestConfig.actions.menus[.selection]
        #expect(selection.frequent == [.done, .notToday, .skipToday])
        #expect(selection.more == [.start, .notStarted, .highPriority, .worm, .unworm, .newSection, .delete])
        for menu in [ActionMenu.taskContext, .habitContext] {
            #expect(!TestConfig.actions.menus[menu].more.contains(.select), "\(menu)")
            #expect(TestConfig.actions.menus[menu].more.contains(.unworm), "\(menu)")
        }
        #expect(TestConfig.actions.definition(.highPriority).undo == .edits)
        #expect(TestConfig.actions.definition(.worm).undo == nil, "Unworm takes a worm back")
    }

    /// The pool menu of a task takes it out of today (Not today) rather than archiving it.
    @Test func thePoolMenuOfATaskOffersNotToday() {
        #expect(TestConfig.actions.menus[.taskContext].actions.contains(.notToday))
        #expect(!TestConfig.actions.menus[.taskContext].actions.contains(.archive))
    }

    /// A tap on an event alert opens Calendar on its day, on a reminder its list, on a habit or a task its page.
    @Test func notificationTapsLeadToCalendarAndReminders() {
        let links = TestConfig.rules.eventLinks
        let start = TestCalendar.date("2026-10-21", "19:00")
        let event: [AnyHashable: Any] = ["kind": "event", "eventStart": start.timeIntervalSince1970]
        let reminder: [AnyHashable: Any] = ["kind": "reminder", "reminder": "REM-1"]
        #expect(NotificationTapTarget.url(for: event, links: links) == links.calendarURL(at: start))
        #expect(NotificationTapTarget.url(for: reminder, links: links) == links.reminderURL(id: "REM-1"))
        #expect(NotificationTapTarget.url(for: ["kind": "habit"], links: links) == nil, "without a name")
        let habit: [AnyHashable: Any] = ["kind": "habit", NotificationPayload.taskKey: "Morning run"]
        #expect(NotificationTapTarget.url(for: habit, links: links) == DeepLink.habit("Morning run"))
    }

    /// Every group and list of the Lists tab has a title text; All statuses has a list per planning level.
    @Test func listsLoadWithTheirTexts() throws {
        let config = try AppConfig.load(bundle: Bundle(for: BundleToken.self).appHostBundle)
        let bundle = Bundle(for: BundleToken.self).appHostBundle
        for title in config.lists.groups.map(\.title) + config.lists.lists.map(\.title) {
            #expect(bundle.localizedString(forKey: title, value: "∅", table: nil) != "∅", "missing text for \(title)")
        }
        let statuses = config.lists.groups.first { $0.id == "statuses" }?.lists.flatMap(\.filter.statuses)
        #expect(statuses == TaskStatus.open + [.done], "Started and Waiting are tags, not lists; the archive is in Settings")
    }


    /// The pages left of the pool are Soon, then Half year, then Someday, each a list of one planning level; a backlog id
    /// naming a list of several levels stops the app at loading.
    @Test func theBacklogNamesListsOfOneStatus() throws {
        let config = try AppConfig.load(bundle: Bundle(for: BundleToken.self).appHostBundle)
        #expect(config.lists.backlogLists.map(\.status) == [.thisWeek, .halfYear, .someday])
        #expect(config.lists.backlogLists.map(\.title) == ["status.thisWeek", "status.halfYear", "status.someday"])
        let lists = try String(contentsOf: TestPaths.configFolder.appendingPathComponent("lists.json"), encoding: .utf8)
        let broken = Data(try lists.replacingOnce("\"backlog\": [\"thisWeek\"", with: "\"backlog\": [\"quick\"").utf8)
        let decoded = try ConfigLoader.decode(TaskListsConfig.self, from: broken, file: "lists.json")
        #expect(throws: ConfigError.self) { try decoded.validate(defaultIcon: TestConfig.defaults.lists.icon, file: "lists.json") }
    }

    /// A planning level misspelt in `day.autoPromoteFrom` stops the app with a config error naming the key; it used to
    /// be read as an unknown status that promoted nothing.
    @Test func aMisspeltAutoPromotionLevelIsAConfigError() throws {
        let rules = try String(contentsOf: TestPaths.configFolder.appendingPathComponent("rules.json"), encoding: .utf8)
        let misspelt = Data(try rules.replacingOnce("\"halfYear\"", with: "\"half_year\"").utf8)
        #expect(TestConfig.rules.day.autoPromoteFrom.map(\.status) == [.halfYear, .someday])
        do {
            _ = try ConfigLoader.decode(RulesConfig.self, from: misspelt, file: "rules.json")
            Issue.record("a misspelt level was accepted")
        } catch let error as ConfigError {
            #expect(error.path.hasPrefix("day.autoPromoteFrom"))
        }
    }

    /// Morning, Day and Evening by default; a pool needs exactly one section for what no routine places.
    @Test func defaultSectionsHaveExactlyOneForTheRest() throws {
        let sections = TestConfig.rules.pool.defaultSections
        #expect(sections.map(\.id) == ["morning", "day", "evening"])
        #expect(sections.map(\.routine) == [.morning, nil, .evening])
        #expect(sections.restID == "day")
        let rules = try String(contentsOf: TestPaths.configFolder.appendingPathComponent("rules.json"), encoding: .utf8)
        for broken in [try rules.replacingOnce(#""catchesRest": true"#, with: #""catchesRest": false"#),
                       try rules.replacingOnce(#""id": "evening""#, with: #""id": "day""#),
                       try rules.replacingOnce(#""routine": "evening""#, with: #""routine": "morning""#)] {
            let decoded = try ConfigLoader.decode(RulesConfig.self, from: Data(broken.utf8), file: "rules.json")
            #expect(throws: ConfigError.self) { try decoded.pool.validate(file: "rules.json") }
        }
    }

    /// "new|old" in icons.json: the newer symbol where the system has it, the fallback otherwise.
    @Test func iconFallbacksPickTheFirstAvailableSymbol() throws {
        let icons = TestConfig.decode(IconSet.self, "icons.json")
        #expect(icons.resolvingFallbacks { $0 == "calendar" }[.listThisWeek] == "calendar")
        #expect(icons.resolvingFallbacks { _ in true }[.listThisWeek] == "7.calendar")
        #expect(icons.resolvingFallbacks { _ in false }[.chevron] == icons[.chevron])
    }

    /// Date detection knows every weekday, month and unit of "in N …".
    @Test func theDateGrammarHasEveryWeekdayMonthAndUnit() throws {
        let config = try AppConfig.load(bundle: Bundle(for: BundleToken.self).appHostBundle)
        #expect(config.dateGrammar.months.keys.sorted() == Array(1...12))
        #expect(Set(config.dateGrammar.weekdays.keys) == Set(Weekday.allCases))
        #expect(Set(config.dateGrammar.units.keys) == Set(DateGrammar.Unit.allCases))
    }

    /// A word in two groups would make a date mean two things: the config is refused, naming the word.
    @Test func aWordInTwoGroupsIsAConfigError() throws {
        let text = try String(contentsOf: TestPaths.configFolder.appendingPathComponent("date-grammar.json"), encoding: .utf8)
        let twice = Data(try text.replacingOnce(#""today": ["today"]"#, with: #""today": ["today", "mon"]"#).utf8)
        let grammar = try ConfigLoader.decode(DateGrammar.self, from: twice, file: "date-grammar.json")
        #expect(throws: ConfigError.self) { try grammar.validate(file: "date-grammar.json") }
        #expect(throws: ConfigError.self) {
            try ConfigLoader.decode(DateGrammar.self, from: Data(try text.replacingOnce(#""monday": ["#, with: #""mondy": ["#).utf8),
                                    file: "date-grammar.json")
        }
    }

    @Test func everyConfigTextHasACatalogEntry() throws {
        let bundle = Bundle(for: BundleToken.self).appHostBundle
        let config = try AppConfig.load(bundle: bundle)
        var keys = config.actions.actions.flatMap { [$0.title, $0.confirmMessage, $0.confirmSubtasks].compactMap { $0 } }
        keys += config.actions.actions.flatMap { action in NoteKind.allCases.compactMap { action.confirmTitle(for: $0) } }
        keys += config.rules.timeEstimates.map(\.label)
        keys += config.rules.pool.defaultSections.map(\.title)
        for key in keys {
            #expect(bundle.localizedString(forKey: key, value: "∅", table: nil) != "∅", "missing text for \(key)")
        }
    }

    /// The Home Screen quick action is "🔫 New" and opens a new task.
    @Test func theQuickActionIsNew() throws {
        let items = try #require(Bundle(for: BundleToken.self).appHostBundle.object(forInfoDictionaryKey: "UIApplicationShortcutItems")
            as? [[String: Any]])
        #expect(items.map { $0["UIApplicationShortcutItemTitle"] as? String } == ["🔫 New"])
        #expect(items.map { $0["UIApplicationShortcutItemType"] as? String } == ["new-task"])
    }

    /// A gap or peek name that is not a design token stops the app with the file and the key, not a zero gap.
    @Test func layoutTokenTypoIsReported() throws {
        let json = Data(#"{"axis": "horizontal", "spacing": "screenHorizontl", "blocks": [{"block": "pool", "size": "fill"}]}"#.utf8)
        let layout = try ConfigLoader.decode(ScreenLayout.self, from: json, file: "today.layout.json")
        #expect(throws: ConfigError.self) { try layout.validate(file: "today.layout.json") }
        let unknownBlock = Data(#"{"axis": "horizontal", "spacing": "screenHorizontal", "blocks": [{"block": "pol", "size": "fill"}]}"#.utf8)
        #expect(throws: ConfigError.self) { try ConfigLoader.decode(ScreenLayout.self, from: unknownBlock, file: "today.layout.json") }
    }

    @Test func layoutTypoIsReported() {
        let json = Data(#"{"axis": "diagonal", "spacing": "blockGap", "blocks": []}"#.utf8)
        #expect(throws: ConfigError.self) { try ConfigLoader.decode(ScreenLayout.self, from: json, file: "today.layout.json") }
        do {
            _ = try ConfigLoader.decode(ScreenLayout.self, from: json, file: "today.layout.json")
        } catch let error as ConfigError {
            #expect(error.description.contains("today.layout.json"))
            #expect(error.description.contains("axis"))
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test func unknownTokenKeyIsReported() {
        let json = Data(#"{"groupGapp": 18}"#.utf8)
        do {
            _ = try ConfigLoader.decode(TokenTable<SpacingToken, Double>.self, from: json, file: "tokens.json")
            Issue.record("expected an error")
        } catch let error as ConfigError {
            #expect(error.description.contains("groupGapp"))
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    /// Taps outside the actions go by what they do: moving rows and loading older weeks are medium, each step of a drag a
    /// selection tick, the rest light.
    @Test func hapticRolesKeepTheirStyles() {
        let haptics = TestConfig.actions.haptics
        #expect(HapticRole.allCases.filter { haptics[$0] == .medium } == [.dropRefused, .reorder, .extend])
        #expect(HapticRole.allCases.filter { haptics[$0] == .light } == [.select, .mark, .drop, .move, .pullArmed])
        #expect(HapticRole.allCases.filter { haptics[$0] == .selection } == [.dragStep])
    }

    /// A role missing from `haptics` or a misspelt style is a config error, not a silent tap.
    @Test func aBadHapticRoleIsAConfigError() throws {
        let json = try String(contentsOf: TestPaths.configFolder.appendingPathComponent("actions.json"), encoding: .utf8)
        for (fragment, replacement) in [("\"extend\": \"medium\"", "\"extnd\": \"medium\""), ("\"extend\": \"medium\"", "\"extend\": \"strong\"")] {
            let broken = Data(try json.replacingOnce(fragment, with: replacement).utf8)
            #expect(throws: ConfigError.self) { try ConfigLoader.decode(ActionRegistry.self, from: broken, file: "actions.json") }
        }
    }

    /// The habit's menus and notification buttons show the habit marks; the flag is the menu's own in actions.json.
    @Test func habitMenusAreMarkedInTheConfig() throws {
        let marked = ActionMenu.allCases.filter { TestConfig.actions.menus[$0].habitMarks }
        #expect(marked == [.habitContext, .habitNotification, .habitDay])
        let json = try String(contentsOf: TestPaths.configFolder.appendingPathComponent("actions.json"), encoding: .utf8)
        let missing = Data(try json.replacingOnce("\"eventContext\":", with: "\"eventContxt\":").utf8)
        #expect(throws: ConfigError.self) { try ConfigLoader.decode(ActionRegistry.self, from: missing, file: "actions.json") }
    }

    @Test func missingActionDefinitionIsReported() throws {
        let registry = ActionRegistry(actions: [], menus: TestConfig.actions.menus, swipes: TestConfig.actions.swipes,
                                      haptics: TestConfig.actions.haptics)
        #expect(throws: ConfigError.self) { try registry.validate(file: "actions.json") }
    }

    /// Every kind of row has its swipes in actions.json; a misspelt kind, side or swipe color is a config error.
    @Test func swipesAreCheckedLikeMenus() throws {
        let json = try String(contentsOf: TestPaths.configFolder.appendingPathComponent("actions.json"), encoding: .utf8)
        for (fragment, replacement) in [("\"archivedHabit\": {", "\"archivedHabbit\": {"), ("\"trailing\": [\n        \"restoreFromTrash\"", "\"traling\": [\n        \"restoreFromTrash\"")] {
            let broken = Data(try json.replacingOnce(fragment, with: replacement).utf8)
            #expect(throws: ConfigError.self) { try ConfigLoader.decode(ActionRegistry.self, from: broken, file: "actions.json") }
        }
        let tinted = Data(try json.replacingOnce("\"forward.end\",\n      \"destructive\": false,\n      \"haptic\": \"light\",\n      \"swipeTint\": \"swipeNeutral\"",
                                                 with: "\"forward.end\",\n      \"destructive\": false,\n      \"haptic\": \"light\",\n      \"swipeTint\": \"swipeNeutrl\"").utf8)
        let registry = try ConfigLoader.decode(ActionRegistry.self, from: tinted, file: "actions.json")
        #expect(throws: ConfigError.self) { try registry.validate(file: "actions.json") }
    }

    @Test func storedSettingsGetDefaultsForNewFields() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = JSONFileStore(directory: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = try AppConfig.load(bundle: Bundle(for: BundleToken.self).appHostBundle)
        try store.writeData(Data(#"{"pool": {"visibleCount": 5}}"#.utf8), to: SettingsStore.fileName)
        let settings = SettingsStore(store: store, defaults: config.defaultSettings).load()
        #expect(settings.pool.visibleCount == 5)
        #expect(settings.vault.tasksFolder == "TaskNotes/Tasks")
        #expect(settings.day.boundary == LocalTime(hour: 4, minute: 0))
    }
}

private final class BundleToken {}

private extension Bundle {
    /// Unit tests run inside the app, whose bundle holds the configs.
    var appHostBundle: Bundle { .main }
}
