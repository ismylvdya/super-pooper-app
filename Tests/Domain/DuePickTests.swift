import Testing
@testable import SuperPooperApp

/// The date sheet: a day, a time and a Time zone that is None unless one is chosen.
struct DuePickTests {
    @Test func withoutAZoneNothingAboutZonesIsWritten() {
        let task = makeTask("Pay rent")
        var pick = DuePick(task: task, today: LocalDate("2026-11-04"))
        pick.day = LocalDate("2026-11-06")
        pick.time = LocalTime("18:20")
        #expect(pick.edits(from: task) == [.due(TaskDue(day: LocalDate("2026-11-06"), time: LocalTime("18:20")))])
    }

    @Test func aChosenZoneIsWritten() {
        let task = makeTask("Call")
        var pick = DuePick(task: task, today: LocalDate("2026-11-04"))
        pick.time = LocalTime("09:00")
        pick.zone = "Asia/Tokyo"
        #expect(pick.edits(from: task).contains(.timeZone("Asia/Tokyo")))
    }

    /// A zone the task already has is not written again; taking it back to None is.
    @Test func onlyAChangedZoneIsWritten() {
        let task = makeTask("Call") { $0.due = TaskDue(day: LocalDate("2026-11-05"), time: LocalTime("09:00")); $0.timeZone = "Asia/Tokyo" }
        var pick = DuePick(task: task, today: LocalDate("2026-11-04"))
        #expect(pick.zone == "Asia/Tokyo")
        #expect(pick.edits(from: task) == [.due(TaskDue(day: LocalDate("2026-11-05"), time: LocalTime("09:00")))])
        pick.zone = nil
        #expect(pick.edits(from: task).contains(.timeZone(nil)))
    }

    @Test func theSheetStartsAtTheTasksDueOrToday() {
        #expect(DuePick(task: makeTask("X"), today: LocalDate("2026-11-04")) == DuePick(day: LocalDate("2026-11-04")))
        let due = TaskDue(day: LocalDate("2026-11-09"), time: LocalTime("07:30"))
        let pick = DuePick(task: makeTask("X") { $0.due = due }, today: LocalDate("2026-11-04"))
        #expect(pick.due == due)
    }
}
