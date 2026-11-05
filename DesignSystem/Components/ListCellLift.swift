import SwiftUI
import UIKit

extension View {
    /// The outline iOS lifts a reordered `List` row with, and drops it back with: `shape` in the cell's bounds. The system
    /// still lifts, scales and drops the real cell; only its outline is given. A `List` reorders through its collection
    /// view's drag and drop delegates, and on iOS 26 their lift no longer follows the row's `contentShape(.dragPreview)`
    /// (a tall row lifted with corners of half its height), so the outline is answered there, where UIKit asks for it.
    /// While dragged, the row's cell stands in the gap at its landing place as a faint copy (`ghostOpacity`).
    func listCellLift(_ shape: PlateShape, ghostOpacity: CGFloat) -> some View {
        background { ListCellLift(shape: shape, ghostOpacity: ghostOpacity) }
    }
}

private struct ListCellLift: UIViewRepresentable {
    let shape: PlateShape
    let ghostOpacity: CGFloat

    func makeUIView(context: Context) -> ListCellLiftView {
        let view = ListCellLiftView()
        view.isUserInteractionEnabled = false
        view.shape = shape
        view.ghostOpacity = ghostOpacity
        return view
    }

    func updateUIView(_ view: ListCellLiftView, context: Context) {
        view.shape = shape
        view.ghostOpacity = ghostOpacity
        view.install()
    }
}

/// Sits in a list cell and hands its list's collection view the lift outline (`ListLiftDelegates`).
private final class ListCellLiftView: UIView {
    var shape: PlateShape?
    var ghostOpacity: CGFloat = 0

    override func didMoveToWindow() {
        super.didMoveToWindow()
        install()
    }

    func install() {
        guard window != nil, let shape else { return }
        var view = superview
        while let current = view, !(current is UICollectionView) { view = current.superview }
        guard let collection = view as? UICollectionView else { return }
        ListLiftDelegates.install(on: collection, shape: shape, ghostOpacity: ghostOpacity)
    }
}

/// The list's own drag and drop delegates with two answers of ours: the preview outline of a lifted or dropped cell, and
/// the faint copy of the dragged row in the gap at its landing place. Everything else goes to the list's delegates unchanged.
final class ListLiftDelegates: NSObject, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    private static var key: UInt8 = 0

    private weak var drag: UICollectionViewDragDelegate?
    private weak var drop: UICollectionViewDropDelegate?
    private(set) var shape: PlateShape
    private(set) var ghostOpacity: CGFloat
    /// The faint copy of the row being dragged, standing in the gap.
    private var ghostCopy: UIView?
    /// Keeps the copy on its cell every frame, while the rows part and also while the finger rests.
    private var ghostLink: CADisplayLink?
    private weak var ghostList: UICollectionView?

    private init(drag: UICollectionViewDragDelegate?, drop: UICollectionViewDropDelegate?, shape: PlateShape, ghostOpacity: CGFloat) {
        self.drag = drag
        self.drop = drop
        self.shape = shape
        self.ghostOpacity = ghostOpacity
    }

    /// Wraps the list's delegates once; a list that set new ones of its own since gets those wrapped.
    static func install(on collection: UICollectionView, shape: PlateShape, ghostOpacity: CGFloat) {
        let installed = objc_getAssociatedObject(collection, &key) as? ListLiftDelegates
        let drag = collection.dragDelegate.flatMap { $0 === installed ? installed?.drag : $0 }
        let drop = collection.dropDelegate.flatMap { $0 === installed ? installed?.drop : $0 }
        if let installed, installed.drag === drag, installed.drop === drop {
            installed.shape = shape
            installed.ghostOpacity = ghostOpacity
            return
        }
        guard drag != nil || drop != nil else { return }
        let delegates = ListLiftDelegates(drag: drag, drop: drop, shape: shape, ghostOpacity: ghostOpacity)
        objc_setAssociatedObject(collection, &key, delegates, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        if drag != nil { collection.dragDelegate = delegates }
        if drop != nil { collection.dropDelegate = delegates }
    }

    /// The outline of the cell at `indexPath`, in its own bounds.
    func parameters(in collection: UICollectionView, at indexPath: IndexPath) -> UIDragPreviewParameters? {
        guard let cell = collection.cellForItem(at: indexPath) else { return nil }
        let parameters = UIDragPreviewParameters()
        let path = UIBezierPath(cgPath: shape.path(in: cell.bounds).cgPath)
        parameters.visiblePath = path
        parameters.shadowPath = path
        parameters.backgroundColor = .clear
        return parameters
    }

    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        parameters(in: collectionView, at: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, dropPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        parameters(in: collectionView, at: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession,
                        at indexPath: IndexPath) -> [UIDragItem] {
        drag?.collectionView(collectionView, itemsForBeginning: session, at: indexPath) ?? []
    }

    /// While a row is dragged, UIKit keeps its own cell in the gap the rows part around at the landing place, hidden, and
    /// hides it again at every layout, so the cell itself cannot be shown there. A faint copy of the row
    /// (`ghostOpacity`) stands in the cell's place instead: how the row will stand once dropped.
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession,
                        withDestinationIndexPath destination: IndexPath?) -> UICollectionViewDropProposal {
        let proposal = drop?.collectionView?(collectionView, dropSessionDidUpdate: session, withDestinationIndexPath: destination)
            ?? UICollectionViewDropProposal(operation: .forbidden)
        if session.localDragSession != nil, ghostLink == nil {
            ghostList = collectionView
            let link = CADisplayLink(target: self, selector: #selector(followGap))
            link.add(to: .main, forMode: .common)
            ghostLink = link
        }
        return proposal
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidEnd session: UIDropSession) {
        drop?.collectionView?(collectionView, dropSessionDidEnd: session)
        removeGhost()
    }

    func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession) {
        drag?.collectionView?(collectionView, dragSessionDidEnd: session)
        removeGhost()
    }

    /// The dragged row's own cell in the gap, as UIKit keeps it out of sight while the session is a reorder of this list.
    /// Not for a drag from elsewhere, and not at the lift, while the cell still stands in its place.
    static func isGap(_ cell: UICollectionViewCell, session: UIDropSession?) -> Bool {
        if let session, session.localDragSession == nil { return false }
        return cell.isHidden || cell.alpha == 0
    }

    /// The picture is taken while the dragged cell still stands in its place, half seen, with its content back from the menu's
    /// preview; from then on the copy stands where the hidden cell is on screen, mid-animation too.
    @objc private func followGap() {
        guard let list = ghostList else { return }
        if ghostCopy == nil, let lifted = list.visibleCells.first(where: { $0.configurationState.cellDragState == .dragging && !$0.isHidden }) {
            ghostCopy = lifted.snapshotView(afterScreenUpdates: false)
            ghostCopy?.isUserInteractionEnabled = false
        }
        guard let copy = ghostCopy, let gap = list.visibleCells.first(where: { Self.isGap($0, session: nil) }) else { return }
        copy.frame = gap.layer.presentation()?.frame ?? gap.frame
        guard copy.superview == nil else { return }
        copy.alpha = ghostOpacity
        list.addSubview(copy)
    }

    /// The drop lands on the cell itself.
    private func removeGhost() {
        ghostLink?.invalidate()
        ghostLink = nil
        ghostCopy?.removeFromSuperview()
        ghostCopy = nil
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        removeGhost()
        drop?.collectionView(collectionView, performDropWith: coordinator)
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || target(for: selector) != nil
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        target(for: selector) ?? super.forwardingTarget(for: selector)
    }

    private func target(for selector: Selector) -> NSObjectProtocol? {
        [drag as NSObjectProtocol?, drop as NSObjectProtocol?].compactMap { $0 }.first { $0.responds(to: selector) }
    }
}
