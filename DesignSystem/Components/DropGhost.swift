import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// The faint copy of a dragged plate where it would land (`opacity.dropGhost`): seen, but not touched or read out. The
    /// pool's gap and the timeline's landing spot draw it; grouped lists show a copy of their cell in the gap the same way
    /// (`ListLiftDelegates`).
    func dropGhost(_ isGhost: Bool = true) -> some View {
        modifier(DropGhost(isGhost: isGhost))
    }
}

extension View {
    /// The room a dragged row keeps where it would land: empty, with nothing drawn in it (the row itself is under the finger).
    func dropGap(_ isGap: Bool = true) -> some View {
        opacity(isGap ? 0 : 1)
            .allowsHitTesting(!isGap)
            .accessibilityHidden(isGap)
    }

    /// A row that left its place: no room at all, the rows below rise. Stays in the hierarchy, so the system's drag keeps
    /// its source. `gap`: the list's spacing, closed with it.
    func closedUp(_ isClosed: Bool, gap: CGFloat) -> some View {
        frame(height: isClosed ? 0 : nil)
            .opacity(isClosed ? 0 : 1)
            .clipped()
            .padding(.bottom, isClosed ? -gap : 0)
            .allowsHitTesting(!isClosed)
            .accessibilityHidden(isClosed)
    }
}

extension View {
    /// A drop target that moves what lands on it: the system shows no plus on the finger, as it does for the copy
    /// `onDrop(of:isTargeted:perform:)` proposes.
    func moveDrop(of types: [UTType], isTargeted: Binding<Bool>, perform: @escaping () -> Bool) -> some View {
        onDrop(of: types, delegate: MoveDrop(isTargeted: isTargeted, perform: perform))
    }
}

private struct MoveDrop: DropDelegate {
    @Binding var isTargeted: Bool
    let perform: () -> Bool

    func dropEntered(info: DropInfo) { isTargeted = true }
    func dropExited(info: DropInfo) { isTargeted = false }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        return perform()
    }
}

private struct DropGhost: ViewModifier {
    @Environment(\.tokens) private var tokens
    let isGhost: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isGhost ? tokens.opacity(.dropGhost) : 1)
            .allowsHitTesting(!isGhost)
            .accessibilityHidden(isGhost)
    }
}
