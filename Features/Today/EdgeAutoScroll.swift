import SwiftUI

/// A list scrolls by itself while the dragged "+" stays at its top or bottom edge (`EdgeScroll`), at the rules' speed,
/// until the "+" leaves the band or the list's end is reached. After each step `onScroll` hears how far the rows moved,
/// so the spot under the finger is found again.
struct EdgeAutoScroll: ViewModifier {
    @Environment(\.rules) private var rules
    /// The dragged "+" on the screen; nil while nothing is dragged.
    let point: CGPoint?
    /// The list's bottom that lies under a bar (the tab bar): the band stands above it.
    var bottomInset: CGFloat = 0
    let onScroll: (CGFloat) -> Void
    @State private var position = ScrollPosition()
    @State private var metrics = Metrics()
    @State private var frame: CGRect = .zero
    @State private var direction = EdgeScroll.Direction.none
    @State private var runner: Task<Void, Never>?
    private static let tick = 1.0 / 60

    struct Metrics: Equatable {
        var offset: CGFloat = 0
        var minimum: CGFloat = 0
        var maximum: CGFloat = 0
    }

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onScrollGeometryChange(for: Metrics.self) { geometry in
                Metrics(offset: geometry.contentOffset.y, minimum: -geometry.contentInsets.top,
                        maximum: geometry.contentSize.height + geometry.contentInsets.bottom - geometry.containerSize.height)
            } action: { _, new in metrics = new }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .onChange(of: point) { _, point in follow(point) }
            .onDisappear(perform: stop)
    }

    private func follow(_ point: CGPoint?) {
        let band = rules.layoutEstimates.poolRowHeight
        let next = point.map { EdgeScroll.direction(y: Double($0.y), top: Double(frame.minY), bottom: Double(frame.maxY - bottomInset), band: band) }
            ?? .none
        guard next != direction else { return }
        direction = next
        runner?.cancel()
        runner = nil
        guard next != .none else { return }
        runner = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.tick))
                guard !Task.isCancelled else { return }
                step()
            }
        }
    }

    private func step() {
        let span = Double(metrics.maximum - metrics.minimum)
        let moved = EdgeScroll.offset(Double(metrics.offset - metrics.minimum), direction,
                                      step: rules.gestures.edgeScrollPointsPerSecond * Self.tick, maximum: span)
        let target = CGFloat(moved) + metrics.minimum
        let delta = target - metrics.offset
        guard abs(delta) > 0.01 else { return }
        position.scrollTo(y: target)
        metrics.offset = target
        onScroll(delta)
    }

    private func stop() {
        runner?.cancel()
        runner = nil
        direction = .none
    }
}

extension View {
    /// Scrolls this scroll view while the dragged "+" (`point`) stays at its edge.
    func edgeAutoScroll(_ point: CGPoint?, bottomInset: CGFloat = 0, onScroll: @escaping (CGFloat) -> Void) -> some View {
        modifier(EdgeAutoScroll(point: point, bottomInset: bottomInset, onScroll: onScroll))
    }
}
