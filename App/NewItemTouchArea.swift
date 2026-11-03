import SwiftUI
import UIKit

/// The touches of the "+": a tap, and a swipe that moves it from its first few points, with no hold. Points are the
/// window's, as SwiftUI's global frames.
struct NewItemTouchArea: UIViewRepresentable {
    let canDrag: Bool
    let onTap: () -> Void
    let onMove: (CGPoint) -> Void
    let onEnd: () -> Void
    let onCancel: () -> Void

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

        @objc func tapped() {
            area?.onTap()
        }

        @objc func panned(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed: area?.onMove(recognizer.location(in: nil))
            case .ended: area?.onEnd()
            case .cancelled, .failed: area?.onCancel()
            default: break
            }
        }
    }
}
