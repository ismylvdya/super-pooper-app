import SwiftUI

extension View {
    /// Lets the row be picked up (long press, then move); the long-press menu still opens without moving. Under the
    /// finger goes `preview` (the row's plate, drawn again: a drag that starts from the long-press menu shows only the
    /// row's text otherwise) at the row's size, lifted as its plate (`lift`).
    @ViewBuilder func taskDragSource<Preview: View>(_ item: DayItem, from source: TaskDragState.Source, drag: TaskDragState?,
                                                    isOn: Bool, lift: PlateCorners, stackCount: Int = 1,
                                                    @ViewBuilder preview: @escaping () -> Preview) -> some View {
        if let drag, isOn {
            modifier(TaskDragSource(item: item, source: source, drag: drag, lift: lift, stackCount: stackCount, preview: preview))
        } else {
            self
        }
    }
}

private struct TaskDragSource<Preview: View>: ViewModifier {
    let item: DayItem
    let source: TaskDragState.Source
    let drag: TaskDragState
    let lift: PlateCorners
    /// How many tasks go along: more than one lifts as a stack (`DragStack`).
    let stackCount: Int
    let preview: () -> Preview
    @State private var size: CGSize?

    func body(content: Content) -> some View {
        content
            .plateLift(lift, for: .dragPreview)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .onDrag { drag.begin(item, from: source) } preview: {
                DragStack(count: stackCount, corners: lift) {
                    // The first of several may be taller or shorter than the row the finger took.
                    preview().frame(width: size?.width, height: stackCount > 1 ? nil : size?.height)
                }
            }
    }
}

/// Dropping on the timeline: the task gets the time under the finger, a habit's block stands there today. What cannot
/// land here shows no sign while it is held; let go, it is refused with a banner (`onRefused`).
