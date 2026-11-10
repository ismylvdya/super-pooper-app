import SwiftUI

/// The fill of a started task's plate (`TaskItem.isStarted`): the started color at full strength at the plate's very
/// left edge, fading evenly to nothing `length` of the plate's width across (`AppSettings.Pool.startedFillLength`).
struct StartedFill: View {
    @Environment(\.tokens) private var tokens
    let length: Double

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(stops: Self.stops(color: tokens.color(.started)), startPoint: .leading, endPoint: .trailing)
                .frame(width: proxy.size.width * CGFloat(min(max(length, 0), 1)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Opaque from the first point, clear at `end` of the way across (the far end unless given).
    static func stops(color: Color, end: CGFloat = 1) -> [Gradient.Stop] {
        [Gradient.Stop(color: color, location: 0), Gradient.Stop(color: color.opacity(0), location: end)]
    }
}

/// The circle before a started task's name (`StartedLook.circle`): the fill's fade across a circle, without an outline,
/// clear already `ratio.startedCircleFade` of the way across, so it reads as half filled.
struct StartedCircle: View {
    @Environment(\.tokens) private var tokens

    var body: some View {
        Circle()
            .fill(LinearGradient(stops: StartedFill.stops(color: tokens.color(.started), end: tokens.ratio(.startedCircleFade)),
                                 startPoint: .leading, endPoint: .trailing))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct StartedLayoutKey: EnvironmentKey {
    static let defaultValue: StartedLayout? = nil
}

extension EnvironmentValues {
    /// How a started task looks in the pool (from the settings); nil draws nothing (widgets, previews).
    var startedLayout: StartedLayout? {
        get { self[StartedLayoutKey.self] }
        set { self[StartedLayoutKey.self] = newValue }
    }
}
