import SwiftUI

/// The row with its tap, title, long-press menu and drag wiring, on its plate.
struct PoolRowContent: View {
    enum PlateKind {
        /// In the pool: on its own plate or on its piece of a routine's plate.
        case pool(PoolRowPlate)
        case slot(isPast: Bool, isCompact: Bool)
    }

    @Environment(\.actions) private var actions
    @Environment(\.tokens) private var tokens
    @Environment(\.highPriorityLook) private var highPriorityLook
    @Environment(\.startedFillLength) private var startedFillLength
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    @Environment(PoolSelection.self) private var selection: PoolSelection?
    let item: DayItem
    var isToday = true
    var isCompact = true
    var titleFont: Font?
    var showsDetails = true
    var titleLineLimit: Int?
    var titleLineHeight: CGFloat?
    var showsDoneState = true
    var plate: PlateKind = .pool(.own)
    /// Extra height under the content (pool rows of long tasks).
    var minimumHeight: CGFloat = 0
    let handler: TaskActionHandler
    /// Where a drag of this row starts from; nil = it cannot be dragged.
    var dragSource: TaskDragState.Source?
    /// The row stands in that day's pool: its menu offers Select, and in Select mode it is picked by a tap.
    var poolDay: LocalDate?

    var body: some View {
        if let selection, selection.isOn, poolDay != nil {
            selectable(selection)
        } else {
            plated
                .plateLift(.row, for: .contextMenuPreview)
                .contextMenu {
                    ActionMenuContent(menu: .context(of: item.task), item: item, isToday: isToday, poolDay: poolDay) {
                        handler.handle($0, taskName: item.id)
                    }
                }
                .taskDragSource(item, from: dragSource ?? .pool, drag: drag, isOn: dragSource != nil, lift: .row) { plated }
        }
    }

    /// Select mode: a tap picks or drops the row, a picked row has an outline and can be dragged with the others picked; no menu.
    private func selectable(_ selection: PoolSelection) -> some View {
        let isSelected = selection.isSelected(item.id)
        return plated
            .allowsHitTesting(false)
            .overlay {
                if isSelected {
                    // Wholly inside the plate and concentric with it, so a routine's shared plate and the row below cut nothing.
                    tokens.plateShape(.row)
                        .strokeBorder(tokens.color(.selectionOutline).opacity(tokens.opacity(.selectionOutline)),
                                      lineWidth: tokens.size(.selectionOutline))
                        .accessibilityIdentifier("pool.selected")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.play(.select)
                selection.toggle(item.id)
            }
            // A picked row lifts all the picked ones with it, as a stack.
            .taskDragSource(item, from: dragSource ?? .pool, drag: drag, isOn: isSelected && dragSource?.wormMembers.isEmpty == false,
                            lift: .row, stackCount: dragSource?.wormMembers.count ?? 1) { plated }
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// The row on its plate: what stands in the pool or on the timeline, and what a drag lifts.
    private var plated: some View {
        let row = TaskRowView(item: item, titleFont: titleFont, showsDetails: showsDetails, isCompact: isCompact,
                              titleLineLimit: titleLineLimit, titleLineHeight: titleLineHeight, showsDoneState: showsDoneState,
                              onOpen: { handler.run(actions.definition(.open), taskName: item.id) })
        let tint = tokens.plateTint(HighPriorityMark(look: highPriorityLook, task: item.task))
        return Group {
            switch plate {
            case .pool(let plate):
                VStack(alignment: .leading, spacing: 0) {
                    row
                    Spacer(minLength: minimumHeight)
                }
                .poolRowPlate(plate, isDone: item.isDone, tint: tint)
            case .slot(let isPast, let isCompact):
                row.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).slotPlate(isPast: isPast, isCompact: isCompact, tint: tint)
            }
        }
        .environment(\.plateGradient, startedFill)
    }

    /// A started task, not done yet, has the started fill over its plate, under its text (`PlateFill`).
    private var startedFill: AnyView? {
        guard let startedFillLength, item.task.status.isStarted, !item.isDone else { return nil }
        return AnyView(StartedFill(length: startedFillLength))
    }
}
