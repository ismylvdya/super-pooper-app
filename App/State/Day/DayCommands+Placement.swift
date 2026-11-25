import Foundation

/// A destination owns placement. A scheduled source only supplies the original block for a habit
/// and indicates when a task's date was a scheduled placement.
enum TaskLanding {
    struct Parent {
        let name: String
        let index: Int
    }

    case list(BacklogList, order: [String], parent: Parent? = nil)
    case pool(day: LocalDate, section: String?, order: [String], parent: Parent? = nil)
    case scheduled(Date)
}

extension DayCommands {
    func relocateTask(_ name: String, to landing: TaskLanding, fromScheduled: Bool, slot: LocalTime?) async {
        guard let task = tasks.task(named: name), let local = localTask(named: name) else { return }
        if task.isHabit {
            await relocateHabit(name, to: landing, slot: slot)
            return
        }
        let context = day.context()
        let destination: TaskPlacementMove.Destination
        let order: [String]
        let parent: TaskLanding.Parent?
        switch landing {
        case .scheduled(let moment):
            destination = .scheduled(moment)
            order = []
            parent = nil
        case .list(let list, let rows, let nested):
            destination = .list(list.status)
            order = rows
            parent = nested
        case .pool(let date, let section, let rows, let nested):
            let selected = sections.snapshot(on: date).order.first { $0.id == section }
            let tag = selected.flatMap { PoolSectionTag.tag(of: $0, definitions: sections.definitions) }
            destination = .pool(date, sectionTag: section == nil ? task.poolSection : tag)
            order = date == context.today ? rows : []
            parent = nested
        }
        var edits = TaskPlacementMove.changes(for: local, to: destination, fromScheduled: fromScheduled, context: context)
        if let parent, let owner = tasks.task(named: parent.name),
           let nesting = SubtaskMove.changes(moving: task.applying(edits), under: owner, index: parent.index, in: tasks.tasks) {
            // The destination decides the planning level and pool membership for this drop.
            edits += nesting.filter { $0.field == .projects || $0.field == .subtaskOrder }
        }
        guard await write(task, edits) else { return }
        switch landing {
        case .pool(let date, let section, _, _):
            placeInSection(name, section, on: date)
            await carrySubtasks(of: task, into: date == context.today)
        case .list, .scheduled:
            sections.update(on: context.today) { $0 = $0.removing([name]) }
            await carrySubtasks(of: task, into: false)
        }
        if order.isEmpty { await derived.publish() }
        else { await setPoolOrder(order) }
    }

    private func relocateHabit(_ name: String, to landing: TaskLanding, slot: LocalTime?) async {
        switch landing {
        case .scheduled(let moment):
            await schedule(name, slot: slot, at: moment)
        case .pool(let date, let section, let order, _):
            guard let slot else { return refuseDrop(name, onto: .pool) }
            await unschedule(name, slot: slot, poolOrder: order, on: date)
            if let section { await relocatePoolRows([(name, section)], order: nil, on: date) }
        case .list(let list, _, _):
            refuseDrop(name, onto: .list(list.title))
        }
    }
}
