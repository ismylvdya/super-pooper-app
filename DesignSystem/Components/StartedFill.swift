import SwiftUI

/// The fill of a started task's plate (`TaskItem.isStarted`): across the whole plate, the started color whole up to the
/// transition, fading evenly to nothing over it, nothing past it (`StartedLayout.fillMiddle`, `fillWidth`; D-192).
struct StartedFill: View {
    @Environment(\.tokens) private var tokens
    let start: Double
    let end: Double

    init(_ layout: StartedLayout) {
        start = layout.fillStart
        end = layout.fillEnd
    }

    var body: some View {
        LinearGradient(stops: Self.stops(color: tokens.color(.started), start: start, end: end), startPoint: .leading, endPoint: .trailing)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Whole up to `start`, nothing from `end` on (a sharp edge when they meet).
    static func stops(color: Color, start: Double, end: Double) -> [Gradient.Stop] {
        [Gradient.Stop(color: color, location: CGFloat(start)), Gradient.Stop(color: color.opacity(0), location: CGFloat(max(end, start)))]
    }
}

/// The circle before a started task's name (`StartedLook.circle`): the started color across a circle, without an
/// outline, fading out around the middle and as wide as the settings say (`StartedLayout.fadeMiddle`, `fadeWidth`). On a
/// taller plate it is a bar with round ends down to the plate's bottom (`StartedLayout.circle`).
struct StartedCircle: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.startedLayout) private var layout

    var body: some View {
        let middle = CGFloat(layout?.fadeMiddle ?? 0.5)
        let half = CGFloat(layout?.fadeWidth ?? 0.5) / 2
        let color = tokens.color(.started)
        Capsule()
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
