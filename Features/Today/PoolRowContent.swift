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
    @Environment(AppModel.self) private var model
    @State private var showsAmount = false
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
    /// The row stands in that day's pool: its menu offers what a pool row does there (Unworm).
    var poolDay: LocalDate?

    var body: some View {
        plated
            .plateLift(.row, for: .contextMenuPreview)
            .contextMenu {
                ActionMenuContent(menu: .context(of: item.task), item: item, isToday: isToday,
                                  poolDay: poolDay, shownDay: handler.shownDay) {
                    if $0.id == .setAmount {
                        showsAmount = true
                    } else {
                        handler.handle($0, taskName: item.id)
                    }
                }
            }
            .popover(isPresented: $showsAmount) {
                if let range = item.task.habit.quantityTracking {
                    HabitQuantityPicker(habit: item.task, day: handler.shownDay ?? poolDay ?? model.context().today,
                                        range: range, model: model)
                }
            }
    }

    /// The row on its plate: what stands in the pool or on the timeline, and what a drag lifts.
    @ViewBuilder private var plated: some View {
        let row = TaskRowView(item: item, titleFont: titleFont, showsDetails: showsDetails, isCompact: isCompact,
                              titleLineLimit: titleLineLimit, titleLineHeight: titleLineHeight, showsDoneState: showsDoneState && item.isFinished,
                              onOpen: { handler.run(actions.definition(.open), taskName: item.id) })
        switch plate {
        case .pool(let plate):
            PlatedPoolRow(item: item, plate: plate, minimumHeight: minimumHeight) { row }
        case .slot(let isPast, let isCompact):
            row.taskSlotPlate(item, isPast: isPast, isCompact: isCompact)
        }
    }
}
