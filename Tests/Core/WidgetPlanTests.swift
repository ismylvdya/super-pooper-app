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
        let notes = makeTask("Notes") { $0.previousEvent = eventLink(to: call) }
        let snapshot = WidgetSnapshot(generatedAt: TestCalendar.context().now, tasks: [notes], events: [], reminders: [],
                                      dayState: DayState(day: LocalDate(TestCalendar.wednesday)), eventsKnown: eventsKnown)
        return WidgetDataSource(config: config, settings: TestConfig.defaults, snapshot: snapshot, calendar: TestCalendar.calendar)
    }

    /// Without Calendar access the app's day shows no "event not found" (D-039); the widget's day did, as if the
    /// calendars were read.
    @Test func withoutCalendarAccessTheWidgetShowsNoMissingEvent() {
        let now = TestCalendar.context().now
        #expect(source(eventsKnown: false).plan(at: now).problems.isEmpty)
        #expect(source(eventsKnown: nil).plan(at: now).problems.isEmpty)
        #expect(source(eventsKnown: true).plan(at: now).problems.map(\.problem) == [.eventNotFound("Call")])
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
}
