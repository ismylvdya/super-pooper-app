import SwiftUI

/// What a drag of several tasks lifts: the row under the finger on top, the plates of at most two more showing under it,
/// and how many tasks go along. One task lifts as it is.
struct DragStack<Top: View>: View {
    @Environment(\.tokens) private var tokens
    let count: Int
    let corners: PlateCorners
    @ViewBuilder let top: Top

    private static var shownUnder: Int { 2 }

    /// Plates of one color lie on each other: their edges tell them apart.
    private var outline: some View {
        tokens.plateShape(corners)
            .strokeBorder(tokens.color(.selectionOutline).opacity(tokens.opacity(.selectionOutline)),
                          lineWidth: tokens.size(.selectionOutline))
    }

    var body: some View {
        if count > 1 {
            let under = min(count - 1, Self.shownUnder)
            let step = tokens.space(.dragStackStep)
            top
                .overlay { outline }
                .background(alignment: .top) {
                    ForEach((1...under).reversed(), id: \.self) { layer in
                        tokens.plateShape(corners)
                            .fill(tokens.color(.plateBackground))
                            .overlay { outline }
                            .scaleEffect(x: 1 - CGFloat(layer) * tokens.ratio(.dragStackShrink), y: 1, anchor: .center)
                            .offset(y: CGFloat(layer) * step)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    Text(verbatim: "\(count)")
                        .font(tokens.font(.chip))
                        .monospacedDigit()
                        .foregroundStyle(tokens.color(.screenBackground))
                        .chipCapsule(tokens.color(.accent))
                }
                .padding(.bottom, CGFloat(under) * step)
        } else {
            top
        }
    }
}
