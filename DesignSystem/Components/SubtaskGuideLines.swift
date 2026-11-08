import SwiftUI

/// A subtask row's part of the lines from its parent (`SubtaskGuide`), drawn in the room its indent leaves: each line
/// starts `gap` above the row, where the row above ends, so the parts of the rows meet.
struct SubtaskGuideLines: View {
    @Environment(\.tokens) private var tokens
    let guide: SubtaskGuide
    /// Where the line turns into the row's plate, from the row's top (the middle of its first line).
    let turnY: CGFloat

    var body: some View {
        GeometryReader { proxy in
            SubtaskGuideShape(guide: guide, indent: tokens.space(.subtaskIndent), gap: tokens.space(.poolRowGap), turnY: turnY,
                              turnRadius: tokens.size(.subtaskLineTurn), height: proxy.size.height)
                .stroke(tokens.color(.subtaskLine), style: StrokeStyle(lineWidth: tokens.size(.subtaskLine), lineCap: .round))
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
        let radius = min(turnRadius, CGFloat(guide.depth) * indent - x, turnY + gap)
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
