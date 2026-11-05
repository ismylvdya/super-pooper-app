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

private struct StartedFillLengthKey: EnvironmentKey {
    static let defaultValue: Double? = nil
}

extension EnvironmentValues {
    /// How far a started task's fill reaches (from the settings); nil draws none (widgets, previews).
    var startedFillLength: Double? {
        get { self[StartedFillLengthKey.self] }
        set { self[StartedFillLengthKey.self] = newValue }
    }
}
