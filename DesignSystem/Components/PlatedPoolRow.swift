import SwiftUI

/// A pool row on its plate in the looks the settings give it, in the app and in the widget alike: the high priority
/// tint (`HighPriorityMark`) and a started task's fill or circle (`StartedLayout`), the name moved right for the circle.
struct PlatedPoolRow<Row: View>: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.highPriorityLook) private var highPriorityLook
    @Environment(\.startedLayout) private var startedLayout
    let item: DayItem
    let plate: PoolRowPlate
    /// Extra height under the content (pool rows of long tasks).
    var minimumHeight: CGFloat = 0
    @ViewBuilder let row: Row
    /// The plate's size, for the started mark and how far the name moves for it.
    @State private var plateSize: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row
            // Only for a long task: in a widget a spacer would take all the room there is.
            if minimumHeight > 0 { Spacer(minLength: minimumHeight) }
        }
        .padding(.leading, startedShift)
        .poolRowPlate(plate, isDone: item.isFinished, tint: tokens.plateTint(HighPriorityMark(look: highPriorityLook, task: item.task)))
        .overlay(alignment: .topLeading) { circle }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { plateSize = $0 }
        .environment(\.plateGradient, started.flatMap { $0.look == .fill ? AnyView(StartedFill(length: $0.fillLength)) : nil })
    }

    private var started: StartedLayout? { startedLayout?.shown(for: item) }

    @ViewBuilder private var circle: some View {
        if let started, let frame = started.circle(plateHeight: plateSize.height, cornerRadius: tokens.plateRadius(.row), sizes: tokens.startedCircleSizes) {
            StartedCircle().frame(width: frame.width, height: frame.height).offset(x: frame.minX, y: frame.minY)
        }
    }

    private var startedShift: CGFloat {
        guard let started else { return 0 }
        return started.titleShift(plateSize: plateSize, cornerRadius: tokens.plateRadius(.row), sizes: tokens.startedCircleSizes,
                                  inset: tokens.space(.plateInner) / 2)
    }
}

extension StartedLayout {
    /// The look the settings give a started task (`AppSettings.Pool`).
    init(_ pool: AppSettings.Pool) {
        self.init(look: pool.startedLook, fillLength: pool.startedFillLength, titleAfterFill: pool.startedTitleAfterFill,
                  circleSize: pool.startedCircleSize, fadeMiddle: pool.startedFadeMiddle, fadeWidth: pool.startedFadeWidth,
                  titleGap: pool.startedTitleGap)
    }

    /// This look for a started task not done yet; nil for any other.
    func shown(for item: DayItem) -> StartedLayout? {
        item.task.isStarted && !item.isDone ? self : nil
    }
}

extension View {
    /// The pool's looks from the settings: high priority, subtask lines and started tasks.
    func poolLooks(_ pool: AppSettings.Pool) -> some View {
        environment(\.highPriorityLook, pool.highPriorityLook)
            .environment(\.subtaskLineLook, SubtaskLineLook(corner: pool.subtaskLineCorner, roundsMiddle: pool.subtaskLineRoundsMiddle))
            .environment(\.startedLayout, StartedLayout(pool))
    }
}
