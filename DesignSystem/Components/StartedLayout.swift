import CoreGraphics

/// A started task's look (`TaskItem.isStarted`): the started color across its whole plate up to a transition, nothing
/// past it, and its name `titleGap` past the transition's end (D-193).
struct StartedLayout: Equatable {
    /// The fill's transition from the started color to nothing: its middle from the plate's left edge and its width, as
    /// shares of the plate's width; left of it the color is whole.
    var fillMiddle: Double
    var fillWidth: Double
    /// Points from the transition's end to the name; below zero the name moves back over the fill, at most to where it
    /// stands on a task not started.
    var titleGap: Double = 0

    /// Where the fill's transition starts and ends, as shares of the plate's width (within the plate).
    var fillStart: Double { min(max(fillMiddle - fillWidth / 2, 0), 1) }
    var fillEnd: Double { min(max(fillMiddle + fillWidth / 2, 0), 1) }

    /// How far right of its usual place (`inset` from the plate's left edge) the name starts: `titleGap` past the
    /// transition's end, never left of its usual place.
    func titleShift(plateWidth: CGFloat, inset: CGFloat) -> CGFloat {
        max(plateWidth * CGFloat(fillEnd) + CGFloat(titleGap) - inset, 0)
    }
}
