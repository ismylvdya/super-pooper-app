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
