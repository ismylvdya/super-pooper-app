import Foundation
import SwiftUI
import Testing
@testable import SuperPooperApp

/// A pool section dragged by its header goes before or after a whole other section, and only within the pool.
@MainActor
struct SectionDropOrderTests {
    private let headers = [SectionDropOrder.Header(id: "morning", midY: 10), SectionDropOrder.Header(id: "day", midY: 100),
                           SectionDropOrder.Header(id: "evening", midY: 300)]

    @Test func belowAHeaderGoesAfterThatSectionAboveBeforeIt() {
        #expect(SectionDropOrder.order(headers: headers, dragged: "evening", at: 101) == ["morning", "day", "evening"])
        #expect(SectionDropOrder.order(headers: headers, dragged: "evening", at: 99) == ["morning", "evening", "day"])
        #expect(SectionDropOrder.order(headers: headers, dragged: "evening", at: 5) == ["evening", "morning", "day"])
        #expect(SectionDropOrder.order(headers: headers, dragged: "morning", at: 301) == ["day", "evening", "morning"])
        #expect(SectionDropOrder.order(headers: headers, dragged: "morning", at: 50) == ["morning", "day", "evening"])
    }

    @Test func aSpotIsInTheSectionOfTheHeaderAboveIt() {
        #expect(SectionDropOrder.section(headers: headers, at: 150) == "day")
        #expect(SectionDropOrder.section(headers: headers, at: 400) == "evening")
        #expect(SectionDropOrder.section(headers: headers, at: 2) == "morning")
        #expect(SectionDropOrder.section(headers: [], at: 2) == nil)
    }

    private func sectionDrag() -> TaskDragState {
        let drag = TaskDragState()
        _ = drag.beginSection("evening")
        return drag
    }

    @Test func thePoolTakesASectionAndShowsItFaintWhereItWouldLand() {
        let drag = sectionDrag()
        let delegate = PoolDropDelegate(drag: drag, animation: .default, layout: { PoolDropLayout() }, canDrop: { _, _ in false },
                                        onDrop: { _, _, _, _ in }, onSectionDrop: { _, _ in }, onRefused: { _ in })
        #expect(delegate.accepts())
        #expect(!drag.isSectionGhost("evening"), "not over the pool yet")
        #expect(drag.hover(sectionOrder: ["morning", "evening", "day"]))
        #expect(drag.isSectionGhost("evening") && !drag.isSectionGhost("day"))
        drag.end()
        #expect(drag.section == nil && !drag.isSectionGhost("evening"))
    }

}
