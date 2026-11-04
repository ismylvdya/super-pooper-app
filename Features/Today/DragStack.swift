import SwiftUI

/// What a drag of several tasks lifts: one row with the selection's outline and, over its corner, a badge saying how many
/// tasks go along. One task lifts as it is.
struct DragStack<Top: View>: View {
    @Environment(\.tokens) private var tokens
    let count: Int
    let corners: PlateCorners
    @ViewBuilder let top: Top

    var body: some View {
        if count > 1 {
            let badge = tokens.size(.dragBadge)
            let radius = tokens.plateRadius(corners)
            top
                .overlay {
                    tokens.plateShape(corners)
                        .strokeBorder(tokens.color(.selectionOutline).opacity(tokens.opacity(.selectionOutline)),
                                      lineWidth: tokens.size(.selectionOutline))
                }
                .padding(.top, badge / 2)
                .padding(.trailing, badge / 2)
                .overlay(alignment: .topTrailing) {
                    Text(verbatim: "\(count)")
                        .font(tokens.font(.chip))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(tokens.color(.screenBackground))
                        .frame(width: badge, height: badge)
                        .background(tokens.color(.accent), in: Circle())
                        .offset(x: -Self.arcInset(radius), y: Self.arcInset(radius))
                }
                .contentShape(.dragPreview, PlateWithBadge(radius: radius, badge: badge))
        } else {
            top.plateLift(corners, for: .dragPreview)
        }
    }

    /// How far inside its bounding box a corner's arc lies on the diagonal: the badge's center stands on the arc.
    static func arcInset(_ radius: CGFloat) -> CGFloat { radius * (1 - 1 / 2.0.squareRoot()) }
}

/// The outline of a lifted row with its badge: the plate, and the circle standing over its top right corner.
private struct PlateWithBadge: Shape {
    let radius: CGFloat
    let badge: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let plate = CGRect(x: rect.minX, y: rect.minY + badge / 2, width: rect.width - badge / 2, height: rect.height - badge / 2)
        path.addPath(PlateShape(cornerRadius: radius).path(in: plate))
        let inset = radius * (1 - 1 / 2.0.squareRoot())
        path.addEllipse(in: CGRect(x: rect.maxX - badge - inset, y: rect.minY + inset, width: badge, height: badge))
        return path
    }
}
