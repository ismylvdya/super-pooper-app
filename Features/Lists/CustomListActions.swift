import SwiftUI

/// Complete all and Delete list, for a menu or a row's context menu.
struct CustomListMenuItems: View {
    @Environment(AppModel.self) private var model
    @Environment(\.actions) private var actions
    let title: String
    @Binding var isConfirmingDelete: Bool

    var body: some View {
        let done = actions.definition(.done)
        let delete = actions.definition(.delete)
        Button {
            Haptics.play(done.haptic)
            Task { await model.completeList(title) }
        } label: {
            Label("customList.completeAll", systemImage: done.icon)
        }
        .accessibilityIdentifier("customList.completeAll")
        Button(role: .destructive) { isConfirmingDelete = true } label: {
            Label("customList.delete", systemImage: delete.icon)
        }
        .accessibilityIdentifier("customList.delete")
    }
}

extension View {
    /// Asks before a list of the user's own is deleted: its tasks go to the trash (the banner offers Undo), the list is
    /// gone. `onDeleted`: the page of the list closes.
    func customListDeletion(_ title: String?, isPresented: Binding<Bool>, onDeleted: @escaping () -> Void = {}) -> some View {
        modifier(CustomListDeletion(title: title, isPresented: isPresented, onDeleted: onDeleted))
    }
}

private struct CustomListDeletion: ViewModifier {
    @Environment(AppModel.self) private var model
    let title: String?
    @Binding var isPresented: Bool
    let onDeleted: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(Text("customList.delete.title \(title ?? "")"), isPresented: $isPresented, titleVisibility: .visible) {
            Button("customList.delete", role: .destructive) {
                guard let title else { return }
                onDeleted()
                Task { await model.deleteList(title) }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("customList.delete.message")
        }
    }
}
