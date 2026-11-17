import SwiftUI

/// A started task's look on a row of a grouped list (the Lists page, Spreader), as on its plate in the pool
/// (`StartedLayout`): the fill across the row's cell, the name (and what is under it) moved right of it as the settings
/// say. The lines from a parent stay where they were (`subtaskGuideShift`).
struct ListRowStarted: ViewModifier {
    @Environment(\.tokens) private var tokens
    let started: StartedLayout?
    /// The row's own inset before its name.
    let inset: CGFloat
    /// The row's cell: the fill and `tint` are cut to it (rounded only at the group's ends).
    let cellShape: UnevenRoundedRectangle
    /// Over the fill: a high-priority task's soft red.
    let tint: Color?
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.leading, shift)
            .environment(\.subtaskGuideShift, shift)
            .background(tint ?? .clear, in: cellShape)
            .background { fill }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    @ViewBuilder private var fill: some View {
        if let started {
            StartedFill(started).clipShape(cellShape)
        }
    }

    /// How much further right the name stands, past its inset (the same at every level).
    private var shift: CGFloat {
        started?.titleShift(plateWidth: width, inset: inset) ?? 0
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
