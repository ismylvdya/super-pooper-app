import Testing
@testable import SuperPooperApp

struct SmokeTests {
    @Test func localDateArithmetic() {
        let date = LocalDate(year: 2026, month: 10, day: 23)!
        #expect(date.adding(days: 9).isoString == "2026-11-01")
        #expect(date.weekday == .friday)
    }
}
