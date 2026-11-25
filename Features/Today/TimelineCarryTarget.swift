import ListEngineChumbulev
import SwiftUI

/// Adapts a timeline column to the task drag space using its visible frame and time scale.
@MainActor
final class TimelineCarryTarget: ListSpaceMember {
    weak var drag: TaskDragState?
    var frame: CGRect = .zero
    var viewport: CGRect = .zero
    var momentAtOffset: (CGFloat) -> Date? = { _ in nil }

    private func moment(_ point: CGPoint) -> Date? {
        guard viewport.contains(point), frame.contains(point) else { return nil }
        return momentAtOffset(point.y - frame.minY)
    }

    func covers(_ point: CGPoint) -> Bool { moment(point) != nil }

    func carriedIn(at point: CGPoint) {
        guard let at = moment(point) else { return }
        if drag?.hover(at: at) == true { Haptics.play(.dragStep) }
    }

    func carriedInEnded(at point: CGPoint) -> ListDrop? {
        moment(point).map { ListDrop(sectionID: "", row: 0, payload: $0) }
    }

    func newRowFrame() -> CGRect? { nil }
    func dropIn(at point: CGPoint) {}
    func dropInEnded(at point: CGPoint) -> ListDrop? { nil }

    func dropInCancelled() {
        drag?.hoverMoment = nil
    }
}

struct TimelineCarryColumn: ViewModifier {
    @Environment(TasksCarry.self) private var carry: TasksCarry?
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    @State private var target = TimelineCarryTarget()
    let name: String
    let viewport: CGRect
    let window: TimelineWindow
    let hourHeight: CGFloat
    let stepMinutes: Int
    let calendar: Calendar

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { target.frame = $0 }
            .onChange(of: viewport, initial: true) { _, viewport in target.viewport = viewport }
            .onChange(of: window, initial: true) { _, _ in updateScale() }
            .onChange(of: hourHeight) { _, _ in updateScale() }
            .onChange(of: stepMinutes) { _, _ in updateScale() }
            .onChange(of: calendar) { _, _ in updateScale() }
            .onAppear {
                target.drag = drag
                carry?.register(name, member: target) { drop in
                    (drop.payload?.base as? Date).map(TaskLanding.scheduled)
                }
            }
            .onDisappear { carry?.unregister(name, member: target) }
    }

    private func updateScale() {
        target.momentAtOffset = { y in
            guard y < CGFloat(window.hours) * hourHeight else { return nil }
            let moment = TaskScheduling.moment(atOffset: Double(y), windowStart: window.start, hourHeight: Double(hourHeight),
                                               stepMinutes: stepMinutes, calendar: calendar)
            return moment < window.end ? moment : moment.addingTimeInterval(-Double(stepMinutes) * 60)
        }
    }
}
