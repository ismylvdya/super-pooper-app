import SwiftUI

/// The row with its tap, title, long-press menu and drag wiring, on its plate.
struct PoolRowContent: View {
    enum PlateKind {
        /// In the pool: on its own plate or on its piece of a routine's plate.
        case pool(PoolRowPlate)
        case slot(isPast: Bool, isCompact: Bool)
    }

    @Environment(\.tokens) private var tokens
    @Environment(\.actions) private var actions
    @Environment(TaskDragState.self) private var drag: TaskDragState?
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

    var body: some View {
        let row = TaskRowView(item: item, titleFont: titleFont, showsDetails: showsDetails, isCompact: isCompact,
                              titleLineLimit: titleLineLimit, titleLineHeight: titleLineHeight, showsDoneState: showsDoneState,
                              onOpen: { handler.run(actions.definition(.open), taskName: item.id) })
        Group {
            switch plate {
            case .pool(let plate):
                VStack(alignment: .leading, spacing: 0) {
                    row
                    Spacer(minLength: minimumHeight)
                }
                .poolRowPlate(plate, isDone: item.isDone)
            case .slot(let isPast, let isCompact):
                row.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).slotPlate(isPast: isPast, isCompact: isCompact)
            }
        }
        .plateLift(.row, for: .contextMenuPreview)
        .contextMenu {
            ActionMenuContent(menu: .context(of: item.task), item: item, isToday: isToday) {
                handler.handle($0, taskName: item.id)
            }
        }
        .taskDragSource(item, from: dragSource ?? .pool, drag: drag, isOn: dragSource != nil)
    }

}
