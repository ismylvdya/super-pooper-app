import Foundation
import Testing
@testable import SuperPooperApp

/// A task dragged over the pool goes in front of the first row below the finger, into the section whose header is above
/// the finger; while it hovers, the sections show it there.
struct PoolDropOrderTests {
    private let headers = [SectionDropOrder.Header(id: "morning", midY: 0), SectionDropOrder.Header(id: "day", midY: 40),
                           SectionDropOrder.Header(id: "evening", midY: 200)]
    private let rows = [PoolDropOrder.Row(id: "Утро — душ 🚿", midY: 20, section: "morning"),
                        PoolDropOrder.Row(id: "Купить молоко", midY: 60, section: "day"),
                        PoolDropOrder.Row(id: "Позвонить в банк", midY: 100, section: "day"),
                        PoolDropOrder.Row(id: "Чтение 📖", midY: 230, section: "evening")]

    @Test func aTaskDroppedUnderEveningsHeaderJoinsEvening() {
        let drop = PoolDropOrder.drop(rows: rows, headers: headers, dragged: "Купить молоко", at: 210)
        #expect(drop.section == "evening")
        #expect(drop.order == ["Утро — душ 🚿", "Позвонить в банк", "Купить молоко", "Чтение 📖"])
    }

    @Test func aTaskDroppedAboveEveningsHeaderStaysInDay() {
        let drop = PoolDropOrder.drop(rows: rows, headers: headers, dragged: "Купить молоко", at: 150)
        #expect(drop.section == "day")
        #expect(drop.order == ["Утро — душ 🚿", "Позвонить в банк", "Купить молоко", "Чтение 📖"])
    }

    @Test func withoutHeadersThereIsNoSection() {
        #expect(PoolDropOrder.drop(rows: rows, headers: [], dragged: "Купить молоко", at: 210).section == nil)
    }

    @Test func whileHoveringTheTaskStandsInItsNewSection() {
        func item(_ name: String) -> DayItem { DayItem(task: makeTask(name), state: .open, problems: []) }
        let sections = [PoolSectionContent(id: "day", title: "section.day", isCustom: false, items: [item("A"), item("B")]),
                        PoolSectionContent(id: "evening", title: "section.evening", isCustom: false, items: [item("C")])]
        let shown = PoolArrangement.hovering(sections, order: ["B", "C", "A"], dragged: item("A"), into: "evening")
        #expect(shown.map { $0.items.map(\.id) } == [["B"], ["C", "A"]])
        let reordered = PoolArrangement.reordered(sections, by: ["evening", "day"])
        #expect(reordered.map(\.id) == ["evening", "day"])
    }
}
