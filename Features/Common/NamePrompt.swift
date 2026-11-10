import SwiftUI

/// What a name prompt asks for: its title, the field's placeholder and the button that makes the thing (text keys).
struct NamePromptText {
    let title: LocalizedStringKey
    let placeholder: LocalizedStringKey
    let create: LocalizedStringKey

    static let section = NamePromptText(title: "section.new.title", placeholder: "section.new.placeholder", create: "section.new.create")
    static let list = NamePromptText(title: "lists.new.title", placeholder: "lists.new.placeholder", create: "lists.new.create")
}

extension View {
    /// The system alert with a field that asks for a new thing's name (a section, a list). Create is offered once
    /// `accepts` gives the name it would take (trimmed, not taken); the field starts empty every time.
    func namePrompt(_ text: NamePromptText, isPresented: Binding<Bool>, accepts: @escaping (String) -> String?,
                    onCreate: @escaping (String) -> Void) -> some View {
        modifier(NamePrompt(text: text, isPresented: isPresented, accepts: accepts, onCreate: onCreate))
    }

    /// A name that is not empty once trimmed.
    func namePrompt(_ text: NamePromptText, isPresented: Binding<Bool>, onCreate: @escaping (String) -> Void) -> some View {
        namePrompt(text, isPresented: isPresented, accepts: NamePrompt.trimmed, onCreate: onCreate)
    }
}

private struct NamePrompt: ViewModifier {
    let text: NamePromptText
    @Binding var isPresented: Bool
    let accepts: (String) -> String?
    let onCreate: (String) -> Void
    @State private var typed = ""

    static func trimmed(_ typed: String) -> String? {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    func body(content: Content) -> some View {
        content
            .alert(text.title, isPresented: $isPresented) {
                TextField(text.placeholder, text: $typed)
                    .accessibilityIdentifier("namePrompt.name")
                Button(text.create) {
                    if let name = accepts(typed) { onCreate(name) }
                }
                .disabled(accepts(typed) == nil)
                Button("common.cancel", role: .cancel) {}
            }
            .onChange(of: isPresented) { _, shown in if shown { typed = "" } }
    }
}
