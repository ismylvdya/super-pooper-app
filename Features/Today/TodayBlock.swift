import SwiftUI

/// Maps layout block ids to block views (unknown ids stop the app at config loading).
struct TodayBlock: View {
    let id: TodayBlockID
    let plan: DayPlan
    let handler: TaskActionHandler
    let bottomInset: CGFloat
    /// The edges under the system tab bar: upright, the bottom of a block that reaches the screen's bottom (lying sideways
    /// the app's own tab bar stands beside the blocks).
    let barEdges: Edge.Set

    var body: some View {
        switch id {
        case .pool: PoolBlock(plan: plan, handler: handler, bottomInset: bottomInset, barEdges: barEdges)
        case .timeline: TimelineBlock(plan: plan, handler: handler, bottomInset: bottomInset, barEdges: barEdges)
        }
    }
}
