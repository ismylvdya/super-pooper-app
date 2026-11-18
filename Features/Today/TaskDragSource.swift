import SwiftUI

extension View {
    /// Lets the row be picked up (long press, then move); the long-press menu still opens without moving. Under the
    /// finger goes `preview` (the row's plate, drawn again: a drag that starts from the long-press menu shows only the
    /// row's text otherwise) at the row's size, lifted as its plate (`lift`).
    @ViewBuilder func taskDragSource<Preview: View>(_ item: DayItem, from source: TaskDragState.Source, drag: TaskDragState?,
                                                    isOn: Bool, lift: PlateCorners,
                                                    @ViewBuilder preview: @escaping () -> Preview) -> some View {
        if let drag, isOn {
            modifier(TaskDragSource(item: item, source: source, drag: drag, lift: lift, preview: preview))
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
    let preview: () -> Preview
    @State private var size: CGSize?

    func body(content: Content) -> some View {
        content
            .plateLift(lift, for: .dragPreview)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .onDrag { drag.begin(item, from: source) } preview: {
                preview().frame(width: size?.width, height: size?.height)
            }
    }
}

/// Dropping on the timeline: the task gets the time under the finger, a habit's block stands there today. What cannot
/// land here shows no sign while it is held; let go, it is refused with a banner (`onRefused`).
