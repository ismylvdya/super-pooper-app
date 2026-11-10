import SwiftUI
import UIKit

/// The touches of the "+": a tap, and a swipe that moves it from its first few points, with no hold. Points are the
/// window's, as SwiftUI's global frames. While it is dragged a second finger anywhere on the screen is followed too
/// (`SecondFingerRecognizer`): how far up it moved, as a share of the screen's height, nil when lifted.
struct NewItemTouchArea: UIViewRepresentable {
    let canDrag: Bool
    let onTap: () -> Void
    let onMove: (CGPoint) -> Void
    let onEnd: () -> Void
    let onCancel: () -> Void
    var onSecondFinger: (CGFloat?) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped)))
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.panned))
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
        context.coordinator.pan = pan
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.area = self
        context.coordinator.pan?.isEnabled = canDrag
    }

    @MainActor
    final class Coordinator: NSObject {
        var area: NewItemTouchArea?
        weak var pan: UIPanGestureRecognizer?
        private var second: SecondFingerRecognizer?

        @objc func tapped() {
            area?.onTap()
        }

        @objc func panned(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                followSecondFinger(in: recognizer.view?.window)
                area?.onMove(recognizer.location(in: nil))
            case .changed: area?.onMove(recognizer.location(in: nil))
            case .ended:
                stopFollowingSecondFinger()
                area?.onEnd()
            case .cancelled, .failed:
                stopFollowingSecondFinger()
                area?.onCancel()
            default: break
            }
        }

        private func followSecondFinger(in window: UIWindow?) {
            guard let window, second == nil else { return }
            let recognizer = SecondFingerRecognizer { [weak self] rise in self?.area?.onSecondFinger(rise) }
            window.addGestureRecognizer(recognizer)
            second = recognizer
        }

        private func stopFollowingSecondFinger() {
            guard let second else { return }
            second.view?.removeGestureRecognizer(second)
            self.second = nil
        }
    }
}
