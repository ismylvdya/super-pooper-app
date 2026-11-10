import SwiftUI

/// A worm's plate is one element for accessibility, its rows inside it.
struct WormElement: ViewModifier {
    let isWorm: Bool

    func body(content: Content) -> some View {
        if isWorm {
            content.accessibilityElement(children: .contain).accessibilityIdentifier("pool.worm")
        } else {
            content
        }
    }
}

/// The pool as a drop target.
struct PoolDropTarget: ViewModifier {
    let drag: TaskDragState?
    let animation: Animation
    let layout: () -> PoolDropLayout
    let canDrop: (DayItem, TaskDragState.Source) -> Bool
    let onDrop: (DayItem, TaskDragState.Source, [String], String?) -> Void
    let onSectionDrop: (String, [String]) -> Void
    let onRefused: (DayItem) -> Void

    func body(content: Content) -> some View {
        if let drag {
            content
                .contentShape(Rectangle())
                .onDrop(of: TaskDragState.types, delegate: PoolDropDelegate(drag: drag, animation: animation, layout: layout,
                                                                            canDrop: canDrop, onDrop: onDrop,
                                                                            onSectionDrop: onSectionDrop,
                                                                            onRefused: onRefused))
        } else {
            content
        }
    }
}
