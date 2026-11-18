import SwiftUI

/// A pool row on its plate in the looks the settings give it, in the app and in the widget alike: the high priority
/// tint (`DesignTokens.plateTint(for:)`) and a started task's fill (`StartedLayout`), the name moved right of it as the settings say.
struct PlatedPoolRow<Row: View>: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.startedLayout) private var startedLayout
    let item: DayItem
    let plate: PoolRowPlate
    /// Extra height under the content (pool rows of long tasks).
    var minimumHeight: CGFloat = 0
    @ViewBuilder let row: Row
    /// The plate's width, for how far a started task's name moves.
    @State private var plateWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row
            // Only for a long task: in a widget a spacer would take all the room there is.
            if minimumHeight > 0 { Spacer(minLength: minimumHeight) }
        }
        .padding(.leading, startedShift)
        .poolRowPlate(plate, isDone: item.isFinished, tint: tokens.plateTint(for: item.task))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { plateWidth = $0 }
        .environment(\.plateGradient, started.map { AnyView(StartedFill($0)) })
    }

    private var started: StartedLayout? { startedLayout?.shown(for: item) }

    private var startedShift: CGFloat {
        started?.titleShift(plateWidth: plateWidth, inset: tokens.space(.plateInner) / 2) ?? 0
    }
}

extension StartedLayout {
    /// The look the settings give a started task (`AppSettings.Pool`).
    init(_ pool: AppSettings.Pool) {
        self.init(fillMiddle: pool.startedFillMiddle, fillWidth: pool.startedFillWidth, titleGap: pool.startedTitleGap)
    }

    /// This look for a started task not done yet; nil for any other.
    func shown(for item: DayItem) -> StartedLayout? {
        item.task.isStarted && !item.isDone ? self : nil
    }
}

extension View {
    /// The pool's looks from the settings: started tasks (on the timeline and in the widget).
    func poolLooks(_ pool: AppSettings.Pool) -> some View {
        environment(\.startedLayout, StartedLayout(pool))
    }
}
