import Foundation
import Testing
@testable import SuperPooperApp

/// The bundled configs load and are complete; config typos produce readable errors.
struct ConfigTests {
    /// Partially and Twice are picked on the Habits page and in the history only; Today and the notifications offer
    /// Done (a twice-a-day habit's second Done is Twice) and Skip today, in red.
    @Test func partialAndTwiceStayOnTheHabitsPage() {
        #expect(TestConfig.actions.menus["habitDay"] == [.unmark, .partial, .done, .twice])
        #expect(TestConfig.actions.menus["habitContext"] == [.unmark, .done, .skipToday])
        #expect(TestConfig.actions.menus["habitNotification"] == [.done, .skipToday])
        #expect(TestConfig.actions.definition(.skipToday).destructive)
        #expect(TestConfig.actions.menus["eventContext"] == [.deleteEvent])
    }

    /// A tap on an event alert opens Calendar on its day, on a reminder its list; habits and tasks stay in the app.
    @Test func notificationTapsLeadToCalendarAndReminders() {
        let links = TestConfig.rules.eventLinks
        let start = TestCalendar.date("2026-10-21", "19:00")
        let event: [AnyHashable: Any] = ["kind": "event", "eventStart": start.timeIntervalSince1970]
        let reminder: [AnyHashable: Any] = ["kind": "reminder", "reminder": "REM-1"]
        #expect(NotificationTapTarget.url(for: event, links: links) == links.calendarURL(at: start))
        #expect(NotificationTapTarget.url(for: reminder, links: links) == links.reminderURL(id: "REM-1"))
        #expect(NotificationTapTarget.url(for: ["kind": "habit"], links: links) == nil)
    }

    /// Every group and list of the Lists tab has a title text; All statuses has a list per planning level.
    @Test func listsLoadWithTheirTexts() throws {
        let config = try AppConfig.load(bundle: Bundle(for: BundleToken.self).appHostBundle)
        let bundle = Bundle(for: BundleToken.self).appHostBundle
        for title in config.lists.groups.map(\.title) + config.lists.lists.map(\.title) {
            #expect(bundle.localizedString(forKey: title, value: "∅", table: nil) != "∅", "missing text for \(title)")
        }
        let statuses = config.lists.groups.first { $0.id == "statuses" }?.lists.flatMap(\.filter.statuses)
        #expect(statuses == TaskStatus.known)
    }

    /// "new|old" in icons.json: the newer symbol where the system has it, the fallback otherwise.
    @Test func iconFallbacksPickTheFirstAvailableSymbol() throws {
        let icons = TestConfig.decode(IconSet.self, "icons.json")
        #expect(icons.resolvingFallbacks { $0 == "calendar" }[.review] == "calendar")
        #expect(icons.resolvingFallbacks { _ in true }[.review] == "7.calendar")
        #expect(icons.resolvingFallbacks { _ in false }[.chevron] == icons[.chevron])
    }

    @Test func bundledConfigsLoad() throws {
        let config = try AppConfig.load(bundle: Bundle(for: BundleToken.self).appHostBundle)
        #expect(config.todayStacked.blocks.map(\.block) == [.pool, .timeline])
        #expect(config.todayStacked.axis == .vertical)
        #expect(config.todaySideBySide.axis == .horizontal)
        #expect(config.sort.pool == PoolSortCriterion.allCases)
        #expect(config.rules.timeEstimates.map(\.minutes) == [2, 15, 60, 240])
        #expect(config.fieldMapping.fields.previousTasks == "previous_task")
    }

    @Test func everyConfigTextHasACatalogEntry() throws {
        let bundle = Bundle(for: BundleToken.self).appHostBundle
        let config = try AppConfig.load(bundle: bundle)
        var keys = config.actions.actions.flatMap { [$0.title, $0.confirmTitle, $0.confirmMessage].compactMap { $0 } }
        keys += config.rules.timeEstimates.map(\.label)
        for key in keys {
            #expect(bundle.localizedString(forKey: key, value: "∅", table: nil) != "∅", "missing text for \(key)")
        }
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

    @Test func missingActionDefinitionIsReported() throws {
        let registry = ActionRegistry(actions: [], menus: [:])
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
