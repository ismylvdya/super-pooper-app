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

    @Test func theTimelineRefusesASection() {
        let delegate = TimelineDropDelegate(drag: sectionDrag(), moment: { _ in Date() }, canDrop: { _, _ in true },
                                            onDrop: { _, _, _ in }, onNewItemDrop: { _ in })
        #expect(!delegate.validate())
    }

    @Test func aBacklogPageRefusesASection() {
        let delegate = BacklogDropDelegate(drag: sectionDrag(), list: "thisWeek", animation: .default, canDrop: { _ in true },
                                           onDrop: { _, _ in })
        #expect(!delegate.validate())
    }

    @Test func thePoolTakesASectionAndShowsItFaintWhereItWouldLand() {
        let drag = sectionDrag()
        let delegate = PoolDropDelegate(drag: drag, animation: .default, layout: { PoolDropLayout() }, canDrop: { _, _ in false },
                                        onDrop: { _, _, _, _ in }, onSectionDrop: { _, _ in }, acceptsNewItem: false,
                                        onNewItemDrop: { _, _ in })
        #expect(delegate.validate())
        #expect(!drag.isSectionGhost("evening"), "not over the pool yet")
        #expect(drag.hover(sectionOrder: ["morning", "evening", "day"]))
        #expect(drag.isSectionGhost("evening") && !drag.isSectionGhost("day"))
        drag.end()
        #expect(drag.section == nil && !drag.isSectionGhost("evening"))
    }

    /// The tab bar's "+" lands on any timeline and in today's pool; a backlog page does not take it.
    @Test func aNewItemLandsOnTheTimelineAndTodaysPoolOnly() {
        let drag = TaskDragState()
        _ = drag.beginNewItem()
        let timeline = TimelineDropDelegate(drag: drag, moment: { _ in Date() }, canDrop: { _, _ in false },
                                            onDrop: { _, _, _ in }, onNewItemDrop: { _ in })
        #expect(timeline.validate())
        let pool = { (accepts: Bool) in
            PoolDropDelegate(drag: drag, animation: .default, layout: { PoolDropLayout() }, canDrop: { _, _ in true },
                             onDrop: { _, _, _, _ in }, onSectionDrop: { _, _ in }, acceptsNewItem: accepts,
                             onNewItemDrop: { _, _ in })
        }
        #expect(pool(true).validate())
        #expect(!pool(false).validate(), "another day's pool")
        let backlog = BacklogDropDelegate(drag: drag, list: "thisWeek", animation: .default, canDrop: { _ in true },
                                          onDrop: { _, _ in })
        #expect(!backlog.validate())
    }
}
