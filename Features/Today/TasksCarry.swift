import ListEngineChumbulev
import SwiftUI

/// A shared space for task rows, with page turns and a mapping from each surface's drop to a task placement.
@MainActor
@Observable
final class TasksCarry {
    let space = ListDragSpace()
    @ObservationIgnored var edges: [PagedStackEdge: CGRect] = [:]
    @ObservationIgnored private var dwell: Task<Void, Never>?
    @ObservationIgnored private var dwellEdge: PagedStackEdge?
    @ObservationIgnored private var destinations: [String: (ListDrop) -> TaskLanding?] = [:]

    func follow(model: AppModel, drag: TaskDragState, day: @escaping () -> DayPlan, dwellSeconds: Double,
                turn: @escaping (PagedStackEdge) -> Void) {
        space.acceptsTargetAt = { [weak self] point in self?.edge(at: point) == nil }
        space.onCarry = { [weak self] event in
            guard let self else { return }
            switch event {
            case .began(let from, let ids):
                guard drag.item == nil, let name = ids.first?.base as? String else { return }
                let item = day().pool.first { $0.id == name } ?? model.task(named: name).map(DayItem.init(listed:))
                if let item { _ = drag.begin(item, from: model.backlogLists.contains { $0.id == from } ? .backlog(from) : .pool) }
            case .moved(let point):
                self.stay(at: point, seconds: dwellSeconds, turn: turn)
            case .released:
                self.stopDwell()
            case .ended:
                self.stopDwell()
                drag.end()
            }
        }
        space.onTransfer = { [weak self] transfer in
            guard let self, let name = transfer.ids.first?.base as? String,
                  let landing = self.landing(transfer, model: model, plan: day()) else { return }
            let source = drag.source
            let fromScheduled: Bool
            if case .timeline = source { fromScheduled = true } else { fromScheduled = false }
            Haptics.play(.drop)
            Task { await model.relocateTask(name, to: landing, fromScheduled: fromScheduled, slot: source.slot) }
        }
    }

    func register(_ name: String, member: ListSpaceMember, destination: @escaping (ListDrop) -> TaskLanding?) {
        space.join(name, member)
        destinations[name] = destination
    }

    func unregister(_ name: String, member: ListSpaceMember) {
        space.leave(name, member)
        destinations[name] = nil
    }

    private func edge(at point: CGPoint) -> PagedStackEdge? {
        edges.first { $0.value.contains(point) }?.key
    }

    private func stay(at point: CGPoint, seconds: Double, turn: @escaping (PagedStackEdge) -> Void) {
        let edge = edge(at: point)
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

    private func stopDwell() {
        dwell?.cancel()
        dwell = nil
        dwellEdge = nil
    }

    static let pool = "pool"

    private func landing(_ transfer: ListDragSpace.Transfer, model: AppModel, plan: DayPlan) -> TaskLanding? {
        if let destination = destinations[transfer.to] { return destination(transfer.drop) }
        let names = transfer.ids.compactMap { $0.base as? String }
        if transfer.to == Self.pool {
            let pool = DayPoolRows(plan: plan, daySections: model.sections(on: plan.today), definitions: model.config.rules.pool.defaultSections)
            let parent = pool.parent(at: transfer.drop).map { TaskLanding.Parent(name: $0, index: transfer.drop.indexInParent) }
            return .pool(day: plan.today, section: transfer.drop.sectionID,
                         order: pool.order(inserting: names, at: transfer.drop), parent: parent)
        }
        guard let list = model.backlogLists.first(where: { $0.id == transfer.to }) else { return nil }
        let listed = BacklogPage.rows(list, plan: plan, model: model).map(\.id)
        let parent = transfer.drop.parentRow.flatMap { listed.indices.contains($0) ? listed[$0] : nil }
            .map { TaskLanding.Parent(name: $0, index: transfer.drop.indexInParent) }
        var order = listed.filter { !names.contains($0) }
        order.insert(contentsOf: names, at: min(transfer.drop.row, order.count))
        return .list(list, order: order, parent: parent)
    }
}
