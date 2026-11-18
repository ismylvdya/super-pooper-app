import Foundation
import Testing
@testable import SuperPooperApp

/// The widgets build the day from the app's snapshot with the same rules as the app.
@MainActor
struct WidgetPlanTests {
    private let config: AppConfig
    private let call = makeEvent("Call", from: "19:00", to: "20:00")

    init() throws {
        config = try AppConfig.load(bundle: .main)
    }

    private func source(eventsKnown: Bool?) -> WidgetDataSource {
        let notes = makeTask("Notes")
        let snapshot = WidgetSnapshot(generatedAt: TestCalendar.context().now, tasks: [notes], events: [], reminders: [],
                                      dayState: DayState(day: LocalDate(TestCalendar.wednesday)), eventsKnown: eventsKnown)
        return WidgetDataSource(config: config, settings: TestConfig.defaults, snapshot: snapshot, calendar: TestCalendar.calendar)
    }

    /// The widget has its own arrangement: its layout, pool and timeline follow it, and the settings it read keep the
    /// app's arrangement as it is.
    @Test func theWidgetHasItsOwnArrangement() {
        var settings = TestConfig.defaults
        settings.today.arrangement = .paged
        settings.today.widgetArrangement = .stacked
        settings.timeline.layout = .twoColumns
        let source = WidgetDataSource(config: config, settings: settings, snapshot: nil, calendar: TestCalendar.calendar)
        #expect(source.arrangement == .stacked)
        #expect(source.settings.today.arrangement == .paged)
        #expect(source.settings.timelineMode(in: source.arrangement) == .halves)
        #expect(source.settings.timelineMode == .aroundNow)
        #expect(source.settings.poolUsesVisibleCount(in: source.arrangement))
        #expect(source.settings.poolUsesVisibleCount, "only the widget shows a set number of rows now: the app's Today is pages")
        settings.today.widgetArrangement = .paged
        #expect(WidgetDataSource(config: config, settings: settings, snapshot: nil, calendar: TestCalendar.calendar).arrangement == .sideBySide)
    }

    /// The app writes what it knows into the snapshot.
    @Test func theSnapshotSaysWhetherTheCalendarsWereRead() async throws {
        let model = try #require(PreviewModel.make()).model
        model.updateSettings { $0.sources.anchorCalendarIDs = [] }
        await model.flushSettings()
        await model.parts.derived.publish()
        #expect(model.parts.services.snapshotStore.load()?.eventsKnown == false)
        model.updateSettings { $0.sources.anchorCalendarIDs = ["demo"] }
        await model.flushSettings()
        await model.parts.derived.publish()
        #expect(model.parts.services.snapshotStore.load()?.eventsKnown == true)
    }

    /// A snapshot left from yesterday: the widget's pool turns with the day, as the file will — what was put off comes
    /// back, and a task dated today comes in.
    @Test func yesterdaysSnapshotTurnsWithTheDay() {
        let yesterday = TestCalendar.context("2026-10-20", "21:00")
        let putOff = makeTask("Put off", inPool: false)
        let dated = makeTask("Dated", inPool: false) { $0.due = TaskDue("2026-10-21") }
        let snapshot = WidgetSnapshot(generatedAt: yesterday.now, tasks: [putOff, dated], events: [], reminders: [],
                                      dayState: DayState(day: LocalDate("2026-10-20")), eventsKnown: true)
        let source = WidgetDataSource(config: config, settings: TestConfig.defaults, snapshot: snapshot, calendar: TestCalendar.calendar)
        #expect(Set(source.plan(at: TestCalendar.context().now).poolNames) == ["Put off", "Dated"])
        #expect(source.plan(at: yesterday.now).poolNames.isEmpty, "the same day keeps the snapshot's pool")
    }
}
