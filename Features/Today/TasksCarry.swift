import ListEngineChumbulev
import SwiftUI

extension EnvironmentValues {
    /// The lists of Tasks a row is carried between (the pool, the backlog pages) and the timeline (`TasksCarry`).
    @Entry var tasksSpace: ListDragSpace?
}

/// A row carried by the list engine across Tasks (`ListDragSpace`): what it is, where it goes, the pages it turns.
/// While it is carried the app's drag knows it (`TaskDragState`), so the timeline shows where it would land; staying at a
/// page's edge turns to that page; let go over another list or the timeline, the app does what a drop there does.
@MainActor
@Observable
final class TasksCarry {
    let space = ListDragSpace()
    /// The neighbours' edges on the screen (`PagedStack`), by their pages' places.
    var edges: [Int: CGRect] = [:]
    @ObservationIgnored private var dwell: Task<Void, Never>?
    @ObservationIgnored private var dwellEdge: Int?
    @ObservationIgnored private(set) var timeline = TimelineCarryTarget()

    /// What the carry does in the app, given what it needs: the model, the drag, the day shown, the turn of pages.
    func follow(model: AppModel, drag: TaskDragState, day: @escaping () -> DayPlan, dwellSeconds: @escaping () -> Double,
                turn: @escaping (Int) -> Void) {
        space.join(TimelineCarryTarget.name, timeline)
        timeline.drag = drag
        space.onCarry = { [weak self] carry in
            guard let self else { return }
            switch carry {
            case .began(let from, let ids):
                guard let name = ids.first?.base as? String, let item = Self.item(name, from: from, model: model, plan: day()) else { return }
                _ = drag.begin(item, from: Self.source(from))
            case .moved(let point):
                self.stay(at: point, seconds: dwellSeconds(), turn: turn)
            case .ended:
                self.dwell?.cancel()
                self.dwellEdge = nil
                drag.end()
            }
        }
        space.onTransfer = { [weak self] transfer in
            guard let self, let name = transfer.ids.first?.base as? String else { return }
            Self.land(name, from: transfer.from, to: transfer.to, drop: transfer.drop, at: self.timeline.landing, model: model, plan: day())
        }
    }

    /// The finger stays over a neighbour's edge: after a while Tasks turns to it.
    private func stay(at point: CGPoint, seconds: Double, turn: @escaping (Int) -> Void) {
        let edge = edges.first { $0.value.contains(point) }?.key
        guard edge != dwellEdge else { return }
        dwell?.cancel()
        dwellEdge = edge
        guard let edge else { return }
        dwell = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            turn(edge)
        }
    }

    /// The names the lists of Tasks have in the space.
    static let pool = "pool"
    static func backlog(_ id: String) -> String { "backlog." + id }

    private static func backlogID(_ name: String) -> String? {
        name.hasPrefix("backlog.") ? String(name.dropFirst("backlog.".count)) : nil
    }

    private static func source(_ list: String) -> TaskDragState.Source {
        backlogID(list).map(TaskDragState.Source.backlog) ?? .pool
    }

    private static func item(_ name: String, from list: String, model: AppModel, plan: DayPlan) -> DayItem? {
        if let item = plan.pool.first(where: { $0.id == name }) { return item }
        return model.task(named: name).map(DayItem.init(listed:))
    }

    /// A row let go over another list of Tasks, or over the timeline: what a drop there does.
    private static func land(_ name: String, from: String, to: String, drop: ListDrop, at moment: Date?, model: AppModel, plan: DayPlan) {
        Haptics.play(.drop)
        let fromBacklog = backlogID(from) != nil
        if to == TimelineCarryTarget.name {
            guard let moment else { return }
            Task {
                if fromBacklog { await model.scheduleFromBacklog(name, at: moment) } else { await model.schedule(name, at: moment) }
            }
        } else if let id = backlogID(to), let list = model.backlogLists.first(where: { $0.id == id }) {
            Task { await model.moveToBacklog(name, list: list, shown: plan.today, fromShownDay: !fromBacklog) }
        } else if to == pool, fromBacklog {
            var order = plan.sections.first { $0.id == drop.sectionID }?.items.map(\.id) ?? []
            order.insert(name, at: min(drop.row, order.count))
            Task { await model.bringFromBacklog(name, to: plan.today, poolOrder: plan.isToday ? order : nil) }
        }
    }
}

/// The timeline as a place a carried row can go (`ListSpaceMember`): over it, the row's block shows where it would land
/// (the app's drag hovers its moment); let go, it gets that time. It opens no place of its own.
@MainActor
final class TimelineCarryTarget: ListSpaceMember {
    static let name = "timeline"
    weak var drag: TaskDragState?
    /// Where the timeline is and how its hours stand, on the screen (the timeline keeps them as it lays itself out).
    var frame: CGRect = .zero
    var hoursTop: CGFloat = 0
    var windowStart = Date.distantPast
    var hourHeight: CGFloat = 1
    var stepMinutes = 5
    var calendar = Calendar.current
    private(set) var landing: Date?

    /// The moment, on the timeline's drop steps, under a point of the window; nil off the timeline.
    func moment(_ point: CGPoint) -> Date? {
        guard frame.contains(point) else { return nil }
        return TaskScheduling.moment(atOffset: Double(point.y - hoursTop), windowStart: windowStart, hourHeight: Double(hourHeight),
                                     stepMinutes: stepMinutes, calendar: calendar)
    }

    func covers(_ point: CGPoint) -> Bool { moment(point) != nil }

    func carriedIn(at point: CGPoint) {
        guard let at = moment(point) else { return }
        drag?.turnAfterStay(.block(.timeline))
        landing = at
        if drag?.hover(at: at) == true { Haptics.play(.dragStep) }
    }

    func carriedInEnded(at point: CGPoint) -> ListDrop? {
        landing = moment(point) ?? landing
        drag?.hoverMoment = nil
        return landing == nil ? nil : ListDrop(sectionID: Self.name, row: 0)
    }

    func newRowFrame() -> CGRect? { nil }
    func dropIn(at point: CGPoint) {}
    func dropInEnded(at point: CGPoint) -> ListDrop? { nil }

    func dropInCancelled() {
        drag?.hoverMoment = nil
        landing = nil
    }
}
