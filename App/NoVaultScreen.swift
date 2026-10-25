import SwiftUI

/// Without a vault (or when it can't be opened) the app explains itself and offers the picker.
/// DEBUG builds also offer the test vault that `sim.sh load-vault` puts into Documents.
struct NoVaultScreen: View {
    @Environment(AppModel.self) private var model
    let message: String?
    @State private var isPickerPresented = false

    var body: some View {
        VStack {
            EmptyStateView(icon: .emptyVault, title: message == nil ? "vault.empty.title" : "vault.error.title",
                           message: message.map { Text(verbatim: $0) } ?? Text("vault.empty.message"),
                           actionTitle: "vault.choose") { isPickerPresented = true }
            #if DEBUG
            Button("vault.useTestVault") {
                let url = URL.documentsDirectory.appendingPathComponent("TestVault", isDirectory: true)
                Task { await model.selectVault(url) }
            }
            .padding(.bottom)
            #endif
        }
        .vaultPicker(isPresented: $isPickerPresented)
    }
}
