import Foundation
import Testing
@testable import SuperPooperApp

/// The same day in different time zones: wall-clock times of tasks and habits stay where the clock says, the logical
/// day turns at the boundary of the local clock, and notes are read and written the same way. The other tests run in
/// Belgrade only; these repeat the essentials far east, far west and across the date line.
@Suite("Time zones")
struct TimeZoneMatrixTests {
    static let zones = ["Europe/Belgrade", "Asia/Jakarta", "America/New_York", "Pacific/Kiritimati", "Pacific/Pago_Pago", "UTC"]

    private func context(_ zone: String, _ day: String = TestCalendar.wednesday, _ time: String = "08:00") -> DayContext {
        let calendar = TestCalendar.calendar(in: zone)
        return DayContext(now: LocalDate(day).startDate(in: calendar, offset: LocalTime(time)), calendar: calendar,
                          boundary: TestConfig.defaults.day.boundary, energyHour: TestConfig.defaults.day.energyHour)
    }

    private func clock(_ date: Date, in context: DayContext) -> String { LocalTime(date, in: context.calendar).string }

    @Test(arguments: zones)
    func theLogicalDayTurnsAtTheLocalBoundary(zone: String) {
        #expect(context(zone, "2026-10-22", "01:30").today == LocalDate("2026-10-21"))
        #expect(context(zone, "2026-10-22", "04:00").today == LocalDate("2026-10-22"))
    }

    @Test(arguments: zones)
    func timedTasksAndHabitsStandAtTheirClockTime(zone: String) throws {
        let context = context(zone)
        let call = makeTask("Call") { $0.due = TaskDue("2026-10-21T16:00") }
        let tonight = makeTask("Night owl") { $0.due = TaskDue("2026-10-22T01:00") }
        let water = makeHabit("Water", status: .habit) { $0.reminderTimes = [LocalTime("09:00")] }
        let plan = DayScenario(tasks: [call, tonight, water, makeTask("Undated")]).build(at: context)
        #expect(clock(try #require(plan.slot("Call")).start, in: context) == "16:00")
        #expect(clock(try #require(plan.slot("Night owl")).start, in: context) == "01:00")
        #expect(clock(try #require(plan.slot("Water")).start, in: context) == "09:00")
        #expect(plan.poolNames.contains("Undated"))
    }

    @Test(arguments: zones)
    func notificationsRingAtTheLocalClockTime(zone: String) {
        let context = context(zone)
        let call = makeTask("Call") { $0.due = TaskDue("2026-10-21T16:00") }
        let planner = NotificationPlanner(horizonDays: 2, limit: 64)
        let planned = planner.plan(tasks: [call], reminders: [], skipped: [], context: context)
        #expect(planned.map { clock($0.fireDate, in: context) } == ["16:00"])
        #expect(planned.map(\.day) == [LocalDate("2026-10-21")])
    }

    /// Read and written on a phone in that zone: the times in the note stay exactly as written, the stamp takes the zone.
    @Test(arguments: zones)
    func notesReadAndWriteTheSameClockTimes(zone: String) async throws {
        let calendar = TestCalendar.calendar(in: zone)
        let note = try await SandboxNote("Позвонить в банк", calendar: FixedCalendar(current: calendar))
        try await note.apply([.due(TaskDue("2026-11-06T09:00"))])
        #expect(try note.text().contains("due: 2026-11-06T09:00\n"))
        #expect(try await note.reload().due == TaskDue("2026-11-06T09:00"))
        let offset = ISO8601.formatWithMilliseconds(note.sandbox.now, timeZone: calendar.timeZone).suffix(6)
        let stamp = try #require(try note.text().split(separator: "\n").first { $0.hasPrefix("date_modified: ") })
        #expect(stamp.hasSuffix(offset))
        // An offset as TaskNotes writes it, `+00:00` at UTC+0 too, never `Z`.
        #expect(stamp.suffix(6).wholeMatch(of: #/[+-]\d\d:\d\d/#) != nil)
    }
}
