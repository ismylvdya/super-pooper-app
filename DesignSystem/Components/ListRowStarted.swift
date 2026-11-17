import SwiftUI

/// A started task's mark on a row of a grouped list (the Lists page, Spreader), as on its plate in the pool
/// (`StartedLayout`): the fill across the row's cell, or the circle before its name with the name (and what is under
/// it) moved right for it. `indent`: how far right a subtask's name stands; the circle stands there too. The lines from
/// a parent stay where they were (`subtaskGuideShift`).
struct ListRowStarted: ViewModifier {
    @Environment(\.tokens) private var tokens
    let started: StartedLayout?
    let indent: CGFloat
    /// The row's own inset before its name.
    let inset: CGFloat
    /// The row's cell: the fill and `tint` are cut to it (rounded only at the group's ends).
    let cellShape: UnevenRoundedRectangle
    /// Over the fill: a high-priority task's soft red.
    let tint: Color?
    @State private var size: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .padding(.leading, shift)
            .environment(\.subtaskGuideShift, shift)
            .background(tint ?? .clear, in: cellShape)
            .background { fill }
            .overlay(alignment: .topLeading) { circle }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
    }

    @ViewBuilder private var fill: some View {
        if let started, started.look == .fill {
            StartedFill(started).clipShape(cellShape)
        }
    }

    /// The circle before the name, where a subtask's name stands.
    @ViewBuilder private var circle: some View {
        if let started, let frame = started.circle(plateHeight: size.height, cornerRadius: tokens.plateRadius(.row),
                                                   sizes: tokens.startedCircleSizes, oneLineHeight: oneLineHeight) {
            StartedCircle().frame(width: frame.width, height: frame.height).offset(x: indent + frame.minX, y: frame.minY)
        }
    }

    private var oneLineHeight: CGFloat { tokens.startedCircleSizes.upperBound }

    /// How much further right the name stands, past its inset (the same at every level: the circle moves with it).
    private var shift: CGFloat {
        guard let started else { return 0 }
        return started.titleShift(plateSize: size, cornerRadius: tokens.plateRadius(.row), sizes: tokens.startedCircleSizes,
                                  inset: inset, oneLineHeight: oneLineHeight)
    }
}

private struct SubtaskGuideShiftKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// How far a started row moved its name right (`ListRowStarted`): the lines from its parent move back by it.
    var subtaskGuideShift: CGFloat {
        get { self[SubtaskGuideShiftKey.self] }
        set { self[SubtaskGuideShiftKey.self] = newValue }
    }
}
