import Foundation
import Testing
@testable import SuperPooperApp

/// `due` is a clock time as TaskNotes writes it; a value with an offset is a moment and is never read as a clock time
/// by cutting the offset off.
struct TaskDueTests {
    @Test func aClockTimeIsReadWithOrWithoutSeconds() {
        #expect(TaskDue(rawValue: "2026-10-23") == TaskDue(day: LocalDate("2026-10-23")))
        #expect(TaskDue(rawValue: "2026-10-23T16:00")?.time == LocalTime("16:00"))
        #expect(TaskDue(rawValue: "2026-10-23 16:00:30.250")?.time == LocalTime("16:00"))
        #expect(TaskDue(rawValue: "2026-10-23T16:00:30")?.rawValue == "2026-10-23T16:00")
    }

    @Test func anOffsetIsNotAClockTime() {
        for text in ["2026-10-23T16:00Z", "2026-10-23T16:00:00+02:00", "2026-10-23T16:00-0500", "2026-10-23T16:00+03"] {
            #expect(TaskDue(rawValue: text) == nil)
            #expect(TaskDue(moment: text, in: TestCalendar.calendar) != nil)
        }
        #expect(TaskDue(rawValue: "2026-10-23T16:00 tomorrow") == nil)
        #expect(TaskDue(moment: "2026-10-23T16:00", in: TestCalendar.calendar) == nil)
    }

    @Test func aMomentLandsOnTheClockOfTheCalendar() {
        #expect(TaskDue(moment: "2026-10-23T16:00Z", in: TestCalendar.calendar) == TaskDue("2026-10-23T18:00"))
        #expect(TaskDue(moment: "2026-10-23T16:00Z", in: TestCalendar.calendar(in: "America/New_York")) == TaskDue("2026-10-23T12:00"))
        #expect(TaskDue(moment: "2026-10-23T01:00+05:30", in: TestCalendar.calendar) == TaskDue("2026-10-22T21:30"))
    }

    @Test func theWrittenClockIgnoresTheOffset() {
        #expect(TaskDue(writtenWallClockOf: "2026-10-20T09:12:44.123+02:00") == TaskDue("2026-10-20T09:12"))
        #expect(TaskDue(writtenWallClockOf: "2026-10-20T23:30Z") == TaskDue("2026-10-20T23:30"))
    }
}
