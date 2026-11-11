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

    /// Opaque from the first point, clear at the far end.
    static func stops(color: Color) -> [Gradient.Stop] {
        [Gradient.Stop(color: color, location: 0), Gradient.Stop(color: color.opacity(0), location: 1)]
    }
}

/// The circle before a started task's name (`StartedLook.circle`): the started color across a circle, without an
/// outline, fading out around the middle and as wide as the settings say (`StartedLayout.fadeMiddle`, `fadeWidth`).
struct StartedCircle: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.startedLayout) private var layout

    var body: some View {
        let middle = CGFloat(layout?.fadeMiddle ?? 0.5)
        let half = CGFloat(layout?.fadeWidth ?? 0.5) / 2
        let color = tokens.color(.started)
        Circle()
            .fill(LinearGradient(stops: [Gradient.Stop(color: color, location: min(max(middle - half, 0), 1)),
                                         Gradient.Stop(color: color.opacity(0), location: min(max(middle + half, 0), 1))],
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
