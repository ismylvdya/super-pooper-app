import SwiftUI

/// Shows the registry's confirmation dialog before a confirmed action runs.
struct ActionConfirmation: ViewModifier {
    @Binding var pending: PendingAction?
    let perform: (PendingAction) -> Void

    func body(content: Content) -> some View {
        content.alert(
            Text(LocalizedStringKey(pending?.action.confirmTitle ?? "")),
            isPresented: Binding(presenting: $pending),
            presenting: pending
        ) { pending in
            Button(LocalizedStringKey(pending.action.title), role: pending.action.destructive ? .destructive : nil) {
                perform(pending)
            }
            Button("common.cancel", role: .cancel) {}
        } message: { pending in
            Text(L10n.format(pending.action.confirmMessage ?? "", pending.taskName))
        }
    }
}

extension View {
    func actionConfirmation(_ pending: Binding<PendingAction?>, perform: @escaping (PendingAction) -> Void) -> some View {
        modifier(ActionConfirmation(pending: pending, perform: perform))
    }
}
