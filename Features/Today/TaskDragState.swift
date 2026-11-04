import SwiftUI
import UniformTypeIdentifiers

/// The task being dragged on Tasks, shared by the pool, the timeline, the backlog pages and the page edges: where it
/// came from, where it would land on the timeline, the pool order and section while it is over the pool and the backlog
/// page it is over. A pool section dragged by its header is a drag without a task, which only the pool takes. The tab
/// bar's "+" (`newItem`) follows the finger by a gesture of its own, not a system drag: the pool (today) and the timeline
/// watch its point and say what letting it go there would do (`setNewItemLanding`).
@MainActor
@Observable
final class TaskDragState {
    enum Source: Equatable {
        case pool
        /// A block on the timeline; `slot`: its time as the note has it (a habit's block moves for today only).
        case timeline(slot: LocalTime?)
        /// A row of a backlog page, by its list's id.
        case backlog(String)
        /// A pool section's header, by the section's id.
        case section(String)
        /// A worm's member: the whole worm goes along, within the pool only.
        case worm(id: String, members: [String])
        /// The tab bar's "+": a new item, made where it lands.
        case newItem

        var slot: LocalTime? {
            if case .timeline(let slot) = self { slot } else { nil }
        }

        var isBacklog: Bool {
            if case .backlog = self { true } else { false }
        }

        /// The members of a worm dragged whole (none for anything else).
        var wormMembers: [String] {
            if case .worm(_, let members) = self { members } else { [] }
        }
    }

    static let types: [UTType] = [.text]
    /// The pool's id for the room a dragged "+" makes there: it becomes the new task's name once it is made.
    static let newItemGap = NewItemPlacement.gap

    private(set) var item: DayItem?
    private(set) var source: Source = .pool
    /// The spot on the timeline under the finger (shown next to the hours).
    var hoverMoment: Date?
    /// The pool with the task at the spot under the finger.
    var poolOrder: [String]?
    /// The section of the spot under the finger.
    private(set) var poolSection: String?
    /// The pool section dragged by its header.
    private(set) var section: String?
    /// The pool's sections with the dragged one at the spot under the finger.
    private(set) var sectionOrder: [String]?
    /// The page a drag asks Tasks to turn to; the screen turns by its pages of the moment and clears it.
    private(set) var turnRequest: TasksPage?
    /// The backlog page under the finger: the task shows there, faint, where it would be listed.
    var backlogTarget: String?
    /// Counts the drags begun: a lifted finger ends only the drag it was dragging.
    private var session = 0
    /// Where the finger holds the dragged "+", on the screen; nil while it stands in its place.
    private(set) var newItemPoint: CGPoint?
    /// The bubble's size, for drawing it under the finger.
    var newItemSize: CGSize = .zero
    /// What letting the "+" go now does, and which target said so.
    private var newItemLanding: (owner: String, land: () -> Void)?
    /// The block the "+" is staying over, and the wait before Tasks turns to it.
    private var dwellPage: TasksPage?
    private var dwell: Task<Void, Never>?

    func begin(_ item: DayItem, from source: Source) -> NSItemProvider {
        reset()
        self.item = item
        self.source = source
        return provider(for: item.id)
    }

    /// The dragged "+" is at `point` on the screen (its first move picks it up).
    func moveNewItem(to point: CGPoint) {
        if source != .newItem {
            reset()
            source = .newItem
        }
        newItemPoint = point
    }

    /// The target under the "+" says what letting it go there does.
    func setNewItemLanding(_ owner: String, _ land: @escaping () -> Void) {
        newItemLanding = (owner, land)
    }

    /// The "+" left the target `owner`.
    func clearNewItemLanding(_ owner: String) {
        if newItemLanding?.owner == owner { newItemLanding = nil }
    }

    /// The finger lifted the "+": it lands where a target took it, and is back in its place either way.
    func releaseNewItem() {
        let land = newItemLanding?.land
        reset()
        land?()
    }

    func cancelNewItem() {
        reset()
    }

    /// What stands under the finger in the pool's order: the dragged task, or the new item's gap.
    var draggedID: String? {
        item?.id ?? (source == .newItem ? Self.newItemGap : nil)
    }

    /// A task or a "+" is being dragged (a section's header is not).
    var isDragging: Bool { draggedID != nil }

    /// A pool section picked up by its header.
    func beginSection(_ id: String) -> NSItemProvider {
        reset()
        section = id
        source = .section(id)
        return provider(for: id)
    }

    /// The finger is over `moment` on the timeline (a drop step); true when the spot moved, a step to feel.
    func hover(at moment: Date) -> Bool {
        guard moment != hoverMoment else { return false }
        hoverMoment = moment
        return true
    }

    /// The pool in the order the finger makes and the section it is in; true when the row passed another or went into
    /// another section, a step to feel.
    func hover(poolOrder order: [String], section: String? = nil) -> Bool {
        guard order != poolOrder || section != poolSection else { return false }
        poolOrder = order
        poolSection = section
        return true
    }

    /// The sections in the order the dragged header makes; true when it passed another, a step to feel.
    func hover(sectionOrder order: [String]) -> Bool {
        guard order != sectionOrder else { return false }
        sectionOrder = order
        return true
    }

    func leavePool() {
        poolOrder = nil
        poolSection = nil
        sectionOrder = nil
    }

    /// The drag reached a page: Tasks turns to it (nothing when it is already in sight).
    func turn(_ page: TasksPage) {
        turnRequest = page
    }

    /// The dragged "+" stays over `page`'s block for `seconds`: only then Tasks turns to it. Merely passing over the
    /// neighbour's edge (the "+" starts right over the timeline's) turns nothing.
    func turnAfterDwell(_ page: TasksPage, seconds: Double) {
        guard page != dwellPage else { return }
        dwellPage = page
        dwell?.cancel()
        dwell = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, self.dwellPage == page else { return }
            self.turn(page)
        }
    }

    func turnHandled() {
        turnRequest = nil
    }

    /// While the task is over the pool its row there is an empty gap the others part around: the task itself is under
    /// the finger. A worm's other members are gaps too.
    func isGap(_ id: String) -> Bool {
        poolOrder != nil && (draggedID == id || source.wormMembers.containsNoteName(id))
    }

    /// Over the backlog page `list` the dragged task is listed there as a faint copy, unless it is already one of its rows.
    func isBacklogGhost(_ id: String, on list: String) -> Bool {
        backlogTarget == list && item?.id == id && source != .backlog(list)
    }

    /// A row dragged from the backlog page `list` closes up once the finger has moved off its lift: the rows below rise
    /// into its place, as in the pool.
    func isBacklogGap(_ id: String, on list: String) -> Bool {
        item?.id == id && source == .backlog(list) && (backlogTarget != nil || poolOrder != nil || hoverMoment != nil)
    }

    /// While its header is dragged over the pool, the section stands faint where it would land.
    func isSectionGhost(_ id: String) -> Bool {
        sectionOrder != nil && section == id
    }

    func end() {
        reset()
    }

    /// The finger dragging has been lifted. A drop ends the drag at once; one let go outside every drop target (or on
    /// one that does not take it) has no drop, so it ends once `seconds` have passed with no drop and no new drag.
    func fingerLifted(settling seconds: Double, delay: Delay = SleepDelay()) async {
        guard item != nil || section != nil else { return }
        let lifted = session
        try? await delay.wait(seconds)
        guard lifted == session else { return }
        reset()
    }

    private func provider(for id: String) -> NSItemProvider {
        session += 1
        return NSItemProvider(object: id as NSString)
    }

    private func reset() {
        item = nil
        section = nil
        source = .pool
        hoverMoment = nil
        backlogTarget = nil
        newItemPoint = nil
        newItemLanding = nil
        dwellPage = nil
        dwell?.cancel()
        leavePool()
    }
}

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
                preview()
                    .frame(width: size?.width, height: size?.height)
                    .plateLift(lift, for: .dragPreview)
            }
    }
}

/// Dropping on the timeline: the task gets the time under the finger, a habit's block stands there today. What cannot
/// land here shows no sign while it is held; let go, it is refused with a banner (`onRefused`).
@MainActor
struct TimelineDropDelegate: DropDelegate {
    let drag: TaskDragState
    let moment: (CGFloat) -> Date
    let canDrop: (DayItem, TaskDragState.Source) -> Bool
    let onDrop: (DayItem, TaskDragState.Source, Date) -> Void
    let onRefused: (DayItem) -> Void

    /// A task lands here when `canDrop` says so.
    func accepts() -> Bool {
        drag.item.map { canDrop($0, drag.source) } ?? false
    }

    func dropEntered(info: DropInfo) {
        drag.turn(.block(.timeline))
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if accepts(), drag.hover(at: moment(info.location.y)) { Haptics.play(.dragStep) }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        drag.hoverMoment = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let item = drag.item else { return false }
        let landing = drag.hoverMoment ?? moment(info.location.y)
        let source = drag.source
        let accepted = accepts()
        drag.end()
        if accepted { onDrop(item, source, landing) } else { onRefused(item) }
        return true
    }
}
