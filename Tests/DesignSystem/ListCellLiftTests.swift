import SwiftUI
import UIKit
import Testing
@testable import SuperPooperApp

/// A grouped list's row dragged to reorder lifts with the plate's outline, rounded by min(the plate radius, half its
/// height), however tall it is (a Soon row): UIKit gets the outline from the list's drag and drop delegates, and the
/// list's own delegates still do the rest.
@MainActor
struct ListCellLiftTests {
    private let tall: CGFloat = 100

    /// UIKit keeps a dragged row's own cell, hidden, in the gap at its landing place; it is shown there faintly instead
    /// (.3), hidden again for the drop animation to land on, and a row again after the drag.
    @Test func theDraggedRowsCellInTheGapIsAFaintCopy() {
        let cell = UICollectionViewCell()
        cell.isHidden = true
        ListLiftDelegates.showGhost(of: cell, opacity: TestConfig.tokens.opacity(.dropGhost))
        #expect(!cell.isHidden)
        #expect(abs(cell.alpha - TestConfig.tokens.opacity(.dropGhost)) < 0.001)
        #expect(cell.alpha > 0 && cell.alpha < 0.5, "super faint")
        ListLiftDelegates.hideGhost(cell)
        #expect(cell.isHidden && cell.alpha == 1)
    }

    /// The cell in the gap is found by its drag state or, where the system only hides it, by being out of sight.
    @Test func theGapIsTheCellUIKitKeepsOutOfSight() {
        let shown = UICollectionViewCell()
        #expect(!ListLiftDelegates.isGap(shown, session: nil))
        let hidden = UICollectionViewCell()
        hidden.isHidden = true
        #expect(ListLiftDelegates.isGap(hidden, session: nil))
        let transparent = UICollectionViewCell()
        transparent.alpha = 0
        #expect(ListLiftDelegates.isGap(transparent, session: nil))
    }

    @Test func aTallReorderedRowLiftsWithThePlateOutline() async throws {
        let tokens = TestConfig.tokens
        let frames = ListGroupFrames()
        let list = List {
            ForEach(0..<3, id: \.self) { index in
                Text(verbatim: "Row \(index)")
                    .frame(height: index == 0 ? tall : nil)
                    .listGroupRow(group: "rows", id: "\(index)", index: index, count: 3, frames: frames)
            }
            .onMove { _, _ in }
        }
        .listGroupStyle()
        .environment(\.tokens, tokens)
        let window = try #require(Self.window(showing: list))
        defer { window.isHidden = true }
        let collection = try await Self.collectionView(in: window, cells: 3)

        let delegates = try #require(collection.dragDelegate as? ListLiftDelegates)
        #expect(collection.dropDelegate === delegates)
        let first = IndexPath(item: 0, section: 0)
        let cell = try #require(collection.cellForItem(at: first))
        let lift = try #require(delegates.collectionView(collection, dragPreviewParametersForItemAt: first))
        let drop = try #require(delegates.collectionView(collection, dropPreviewParametersForItemAt: first))
        for parameters in [lift, drop] {
            let outline = try #require(parameters.visiblePath)
            #expect(outline.bounds.integral == cell.bounds.integral)
            #expect(cell.bounds.height > tall)
            // The plate's own corner: square enough just below it, where a capsule's would still be cut away.
            let belowCorner = tokens.radius(.plate) * 1.75
            #expect(outline.contains(CGPoint(x: 1, y: belowCorner)))
            #expect(!outline.contains(CGPoint(x: 1, y: 1)))
            #expect(parameters.backgroundColor == .clear)
        }
        // The list's own answers still come from the list.
        let dropUpdate = #selector(UICollectionViewDropDelegate.collectionView(_:dropSessionDidUpdate:withDestinationIndexPath:))
        #expect(delegates.responds(to: dropUpdate))
    }

    private static func window(showing view: some View) -> UIWindow? {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return nil }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
        window.rootViewController = UIHostingController(rootView: view)
        window.isHidden = false
        return window
    }

    /// The list's collection view, once it shows `cells` rows.
    private static func collectionView(in window: UIWindow, cells: Int) async throws -> UICollectionView {
        for _ in 0..<40 {
            window.layoutIfNeeded()
            if let collection = find(in: window), collection.visibleCells.count >= cells { return collection }
            try await Task.sleep(for: .milliseconds(50))
        }
        return try #require(find(in: window))
    }

    private static func find(in view: UIView) -> UICollectionView? {
        if let collection = view as? UICollectionView { return collection }
        return view.subviews.lazy.compactMap(find).first
    }
}
