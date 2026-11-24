import SwiftUI
import UIKit

/// Gives horizontal paging first refusal of pans that start in Tasks, including pans on UIKit lists.
/// UIKit can then leave a vertical pan to the original scroll view before it moves any content.
struct TasksPagePan: UIViewRepresentable {
    let axisRatio: Double
    let canBegin: () -> Bool
    let onChange: (CGFloat) -> Void
    let onEnd: (CGFloat, CGFloat, CGFloat) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> Anchor {
        let anchor = Anchor()
        anchor.isUserInteractionEnabled = false
        anchor.onWindowChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        context.coordinator.anchor = anchor
        return anchor
    }

    func updateUIView(_ anchor: Anchor, context: Context) {
        context.coordinator.pagePan = self
    }

    static func dismantleUIView(_ anchor: Anchor, coordinator: Coordinator) {
        coordinator.attach(to: nil)
    }

    final class Anchor: UIView {
        var onWindowChange: ((UIWindow?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChange?(window)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var anchor: Anchor?
        var pagePan: TasksPagePan?
        private lazy var pan: UIPanGestureRecognizer = {
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(panned))
            recognizer.maximumNumberOfTouches = 1
            recognizer.delegate = self
            return recognizer
        }()

        func attach(to window: UIWindow?) {
            guard pan.view !== window else { return }
            pan.view?.removeGestureRecognizer(pan)
            window?.addGestureRecognizer(pan)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let anchor, pagePan?.canBegin() == true else { return false }
            return anchor.bounds.contains(touch.location(in: anchor))
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pagePan, pagePan.canBegin() else { return false }
            let translation = pan.translation(in: pan.view)
            let direction = translation == .zero ? pan.velocity(in: pan.view) : translation
            return TodaySwipe.isHorizontal(width: direction.x, height: direction.y, axisRatio: pagePan.axisRatio)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            guard let scroll = other.view as? UIScrollView else { return false }
            return other === scroll.panGestureRecognizer
        }

        @objc private func panned() {
            guard let pagePan else { return }
            let offset = pan.translation(in: pan.view).x
            switch pan.state {
            case .began, .changed:
                pagePan.onChange(offset)
            case .ended:
                let speed = pan.velocity(in: pan.view).x
                let rate = UIScrollView.DecelerationRate.normal.rawValue
                let projected = offset + (speed / 1_000) * rate / (1 - rate)
                pagePan.onEnd(offset, projected, speed)
            case .cancelled, .failed:
                pagePan.onCancel()
            default:
                break
            }
        }
    }
}
