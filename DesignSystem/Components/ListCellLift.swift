import SwiftUI
import UIKit

extension View {
    /// The outline iOS lifts a reordered `List` row with, and drops it back with: `shape` in the cell's bounds. The system
    /// still lifts, scales and drops the real cell; only its outline is given. A `List` reorders through its collection
    /// view's drag and drop delegates, and on iOS 26 their lift no longer follows the row's `contentShape(.dragPreview)`
    /// (a tall row lifted with corners of half its height), so the outline is answered there, where UIKit asks for it.
    func listCellLift(_ shape: PlateShape) -> some View {
        background { ListCellLift(shape: shape) }
    }
}

private struct ListCellLift: UIViewRepresentable {
    let shape: PlateShape

    func makeUIView(context: Context) -> ListCellLiftView {
        let view = ListCellLiftView()
        view.isUserInteractionEnabled = false
        view.shape = shape
        return view
    }

    func updateUIView(_ view: ListCellLiftView, context: Context) {
        view.shape = shape
        view.install()
    }
}

/// Sits in a list cell and hands its list's collection view the lift outline (`ListLiftDelegates`).
private final class ListCellLiftView: UIView {
    var shape: PlateShape?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        install()
    }

    func install() {
        guard window != nil, let shape else { return }
        var view = superview
        while let current = view, !(current is UICollectionView) { view = current.superview }
        guard let collection = view as? UICollectionView else { return }
        ListLiftDelegates.install(on: collection, shape: shape)
    }
}

/// The list's own drag and drop delegates with one answer of ours: the preview outline of a lifted or dropped cell.
/// Everything else goes to the list's delegates unchanged; the gap at the landing place stays empty, as UIKit keeps it.
final class ListLiftDelegates: NSObject, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    private static var key: UInt8 = 0

    private weak var drag: UICollectionViewDragDelegate?
    private weak var drop: UICollectionViewDropDelegate?
    private(set) var shape: PlateShape

    private init(drag: UICollectionViewDragDelegate?, drop: UICollectionViewDropDelegate?, shape: PlateShape) {
        self.drag = drag
        self.drop = drop
        self.shape = shape
    }

    /// Wraps the list's delegates once; a list that set new ones of its own since gets those wrapped.
    static func install(on collection: UICollectionView, shape: PlateShape) {
        let installed = objc_getAssociatedObject(collection, &key) as? ListLiftDelegates
        let drag = collection.dragDelegate.flatMap { $0 === installed ? installed?.drag : $0 }
        let drop = collection.dropDelegate.flatMap { $0 === installed ? installed?.drop : $0 }
        if let installed, installed.drag === drag, installed.drop === drop {
            installed.shape = shape
            return
        }
        guard drag != nil || drop != nil else { return }
        let delegates = ListLiftDelegates(drag: drag, drop: drop, shape: shape)
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

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
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
