import ListEngineChumbulev
import SwiftUI

extension View {
    /// The tab bar's "+" carried over a list of the engine (`TaskDragState`): while the finger is over the list, the list
    /// opens its place for it (`ListDropIn`), and letting it go there lands it: the list says where (`onDropIn`). `takes`:
    /// the list is the page in sight.
    func engineNewItem(_ dropIn: ListDropIn, owner: String, takes: @escaping () -> Bool = { true }) -> some View {
        modifier(EngineNewItem(dropIn: dropIn, owner: owner, takes: takes))
    }
}

private struct EngineNewItem: ViewModifier {
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    let dropIn: ListDropIn
    let owner: String
    let takes: () -> Bool
    @State private var frame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .onChange(of: drag?.newItemPoint) { _, point in
                guard let drag else { return }
                guard let point, drag.source == .newItem, takes(), frame.contains(point) else {
                    dropIn.cancel()
                    drag.clearNewItemLanding(owner)
                    return
                }
                dropIn.move(to: point)
                drag.setNewItemLanding(owner) {
                    Haptics.play(.drop)
                    dropIn.end(at: point)
                }
            }
    }
}
