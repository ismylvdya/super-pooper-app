import Testing
@testable import SuperPooperApp

/// Weeks run Monday to Sunday: one rule for "this week", the habit grid, the weekly goal and the statistics.
struct LocalDateWeekTests {
    @Test(arguments: ["2026-10-19", "2026-10-22", "2026-10-25"])
    func aDayBelongsToItsMondayToSundayWeek(day: String) throws {
        let date = try #require(LocalDate(isoString: day))
        #expect(date.weekStart == LocalDate(isoString: "2026-10-19"))
        #expect(date.weekEnd == LocalDate(isoString: "2026-10-25"))
        #expect(date.weekStart.weekday == .monday)
        #expect(date.weekEnd.weekday == .sunday)
    }
}
