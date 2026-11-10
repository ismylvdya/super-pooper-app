import UIKit

/// A second finger on the screen while the "+" is dragged: how far up it is from where it touched, as a share of the
/// window's height (down is negative), and nil when it is lifted. It is put on the window only for the drag (`NewItemTouchArea`), so nothing else sees it
/// then, and taken off after.
@MainActor
final class SecondFingerRecognizer: UIGestureRecognizer {
    private let onRise: (CGFloat?) -> Void
    private weak var touch: UITouch?
    private var start: CGPoint = .zero

    init(onRise: @escaping (CGFloat?) -> Void) {
        self.onRise = onRise
        super.init(target: nil, action: nil)
        cancelsTouchesInView = true
        delaysTouchesBegan = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard touch == nil, let first = touches.first else { return }
        touch = first
        start = first.location(in: nil)
        state = .began
        onRise(0)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch, touches.contains(touch) else { return }
        let height = max(view?.bounds.height ?? 1, 1)
        onRise((start.y - touch.location(in: nil).y) / height)
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        lift(touches, as: .ended)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        lift(touches, as: .cancelled)
    }

    override func reset() {
        touch = nil
    }

    // Nothing else on the screen takes the second finger while the "+" is dragged.
    override func canBePrevented(by preventing: UIGestureRecognizer) -> Bool { false }
    override func canPrevent(_ prevented: UIGestureRecognizer) -> Bool { true }

    private func lift(_ touches: Set<UITouch>, as end: State) {
        guard let touch, touches.contains(touch) else { return }
        onRise(nil)
        state = end
    }
}
