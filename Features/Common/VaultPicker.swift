import SwiftUI

/// The system folder picker for the Obsidian vault; the choice is stored as a bookmark.
struct VaultPickerModifier: ViewModifier {
    @Environment(AppModel.self) private var model
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.fileImporter(isPresented: $isPresented, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            Task { await model.selectVault(url) }
        }
    }
}

extension View {
    func vaultPicker(isPresented: Binding<Bool>) -> some View {
        modifier(VaultPickerModifier(isPresented: isPresented))
    }
}
