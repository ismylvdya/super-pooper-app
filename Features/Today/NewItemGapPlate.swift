import SwiftUI

/// The room a "+" dragged over the pool makes: as tall as a one-line plate, with nothing in it, as a dragged task's gap.
/// As a subtask (`depth` above 0) it stands shifted right like one, and the line from its parent comes down into it,
/// fading out to the right over the empty room.
struct NewItemGapPlate: View {
    @Environment(\.tokens) private var tokens
    var depth = 0
    /// Extra lines for the estimate a second finger picked, as a task of that estimate stands in the pool.
    var extraLines = 0

    var body: some View {
        VStack(spacing: 0) {
            Text(verbatim: " ").font(tokens.font(.taskTitle))
            Spacer(minLength: CGFloat(extraLines) * tokens.uiFont(.taskTitle).lineHeight)
        }
            .frame(maxWidth: .infinity, alignment: .leading)
            .poolRowPlate(.own, isDone: false)
            .dropGap()
            .padding(.leading, CGFloat(depth) * tokens.subtaskIndent)
            .background(alignment: .topLeading) {
                if depth > 0 { line }
            }
    }

    private var line: some View {
        let indent = tokens.subtaskIndent
        let start = CGFloat(depth - 1) * indent + indent / 2
        let reach = start + indent * tokens.ratio(.subtaskLineFade)
        return GeometryReader { proxy in
            SubtaskGuideShape(guide: SubtaskGuide(depth: depth, isLast: true, passes: Array(repeating: false, count: depth - 1)),
                              indent: indent, gap: tokens.space(.poolRowGap),
                              turnY: (tokens.space(.rowVertical) + tokens.uiFont(.taskTitle).lineHeight) / 2,
                              turnRadius: tokens.size(.subtaskLineTurn), height: proxy.size.height, reach: reach)
                .stroke(LinearGradient(stops: [.init(color: tokens.color(.subtaskLine), location: 0),
                                               .init(color: tokens.color(.subtaskLine), location: (start + indent / 2) / proxy.size.width),
                                               .init(color: tokens.color(.subtaskLine).opacity(0), location: reach / proxy.size.width)],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: tokens.size(.subtaskLine), lineCap: .butt))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
