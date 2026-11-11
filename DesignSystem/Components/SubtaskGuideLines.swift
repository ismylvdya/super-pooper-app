import SwiftUI

/// A subtask row's part of the lines from its parent (`SubtaskGuide`), drawn in the room its indent leaves: each line
/// starts `gap` above the row, where the row above ends, so the parts of the rows meet.
struct SubtaskGuideLines: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.subtaskLineLook) private var look
    let guide: SubtaskGuide
    /// Where the line turns into the row's plate, from the row's top (the middle of its first line).
    let turnY: CGFloat

    var body: some View {
        GeometryReader { proxy in
            SubtaskGuideShape(guide: guide, indent: tokens.subtaskIndent, gap: tokens.space(.poolRowGap), turnY: turnY,
                              turnRadius: look.corner, roundsMiddle: look.roundsMiddle, height: proxy.size.height)
                .stroke(tokens.color(.subtaskLine), style: StrokeStyle(lineWidth: tokens.size(.subtaskLine), lineCap: .butt))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The lines themselves: in the middle of each level's indent, down past the row or into its plate.
struct SubtaskGuideShape: Shape {
    let guide: SubtaskGuide
    let indent: CGFloat
    let gap: CGFloat
    let turnY: CGFloat
    let turnRadius: CGFloat
    /// Off: where the line goes on down, the turn leaves it at a right angle.
    var roundsMiddle = true
    let height: CGFloat
    /// How far right the turn goes; nil: to the row's plate.
    var reach: CGFloat?

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (level, passes) in guide.passes.enumerated() where passes {
            let x = CGFloat(level) * indent + indent / 2
            path.move(to: CGPoint(x: x, y: -gap))
            path.addLine(to: CGPoint(x: x, y: height))
        }
        let x = CGFloat(guide.depth - 1) * indent + indent / 2
        let end = reach ?? CGFloat(guide.depth) * indent
        guard guide.isLast || roundsMiddle else {
            path.move(to: CGPoint(x: x, y: -gap))
            path.addLine(to: CGPoint(x: x, y: height))
            path.move(to: CGPoint(x: x, y: turnY))
            path.addLine(to: CGPoint(x: end, y: turnY))
            return path
        }
        let radius = max(min(turnRadius, CGFloat(guide.depth) * indent - x, turnY + gap), 0)
        path.move(to: CGPoint(x: x, y: -gap))
        path.addLine(to: CGPoint(x: x, y: turnY - radius))
        path.addQuadCurve(to: CGPoint(x: x + radius, y: turnY), control: CGPoint(x: x, y: turnY))
        path.addLine(to: CGPoint(x: end, y: turnY))
        if !guide.isLast {
            path.move(to: CGPoint(x: x, y: turnY - radius))
            path.addLine(to: CGPoint(x: x, y: height))
        }
        return path
    }
}

/// How the lines from parents to subtasks turn (Settings → Pool & Timeline → Subtask lines).
struct SubtaskLineLook: Equatable {
    var corner: CGFloat = 0
    var roundsMiddle = true
}

private struct SubtaskLineLookKey: EnvironmentKey {
    static let defaultValue = SubtaskLineLook()
}

extension EnvironmentValues {
    var subtaskLineLook: SubtaskLineLook {
        get { self[SubtaskLineLookKey.self] }
        set { self[SubtaskLineLookKey.self] = newValue }
    }
}
