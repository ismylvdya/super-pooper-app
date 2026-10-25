import Testing
@testable import SuperPooper

/// Notes are listed by name in one order everywhere: case does not matter and numbers read as numbers.
struct NameOrderTests {
    @Test func namesIgnoreCaseAndReadNumbersAsNumbers() {
        #expect(NameOrder.sorted(["Задача 10", "банк", "Задача 2", "Аптека"]) == ["Аптека", "банк", "Задача 2", "Задача 10"])
    }

    @Test func searchAndPickersUseTheSameOrder() {
        let tasks = ["Полить 10 цветов", "полить 2 цветка", "Позвонить"].map { makeTask($0) }
        #expect(SearchMatcher.tasks(tasks, matching: "пол").map(\.name) == ["полить 2 цветка", "Полить 10 цветов"])
        #expect(NameOrder.sorted(tasks).map(\.name) == ["Позвонить", "полить 2 цветка", "Полить 10 цветов"])
    }
}
