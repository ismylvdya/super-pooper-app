import Foundation

/// What a task store can do beyond the basics. An action or a page that needs something the store cannot do is left out.
struct StoreCapabilities: Equatable, Sendable {
    /// Opening an item in the app the store belongs to (Obsidian).
    var opensExternally: Bool
    /// A trash deleted items go to and can be put back from.
    var hasTrash: Bool
}

/// Which actions of a menu an item offers now, and which of them is the mark it already has (shown, not selectable): by
/// the item's state, the day the menu is on, and what the store can do.
struct ActionAvailability: Sendable {
    struct Entry: Equatable, Sendable {
        let action: ActionID
        let isCurrent: Bool
    }

    let capabilities: StoreCapabilities
    /// Skip today and Not today only make sense on today's page.
    var isToday = true

    /// `actions`: the menu's actions in order; `item`: what the menu is about (nil: no state to judge by).
    func entries(_ actions: [ActionID], for item: DayItem?) -> [Entry] {
        let offersTwice = actions.contains(.twice)
        return actions.filter { isAvailable($0, for: item) }.map { action in
            Entry(action: action, isCurrent: item.map { isCurrentMark(action, of: $0, offersTwice: offersTwice) } ?? false)
        }
    }

    func isAvailable(_ action: ActionID, for item: DayItem?) -> Bool {
        if action == .openInObsidian { return capabilities.opensExternally }
        guard let item else { return true }
        switch action {
        case .twice: return !item.isHabit || item.task.isTwiceADay || item.state == .marked(.twice)
        case .unmark: return item.isDone
        case .skipToday: return isToday && item.isHabit && !item.isFinished
        case .notToday: return isToday && NotToday.isAvailable(for: item)
        case .returnFromDone: return !item.isHabit && item.isDone
        case .start: return !item.isHabit && !item.isDone && !item.task.status.isCompleted && !item.task.status.isStarted
        case .notStarted: return !item.isHabit && item.task.status.isStarted
        case .archive: return !item.task.isArchived
        case .restoreFromArchive: return item.task.isArchived
        default: return true
        }
    }

    /// The swipe buttons of a row: the actions of `actions` it offers now, in order, without the mark it already has
    /// (a swipe button cannot be shown and not pressed).
    func swipe(_ actions: [ActionID], for item: DayItem?) -> [ActionID] {
        entries(actions, for: item).filter { !$0.isCurrent }.map(\.action)
    }

    private func isCurrentMark(_ action: ActionID, of item: DayItem, offersTwice: Bool) -> Bool {
        switch action {
        case .done:
            // Without Twice in the menu, Done on a twice-a-day habit done once goes on to Twice (`HabitMarking.menuDone`).
            guard item.state == .marked(.done) else { return false }
            return offersTwice || HabitMarking.menuDone(current: .done, twiceADay: item.task.isTwiceADay) == .done
        case .partial: return item.state == .marked(.partial)
        case .twice: return item.state == .marked(.twice)
        default: return false
        }
    }
}
