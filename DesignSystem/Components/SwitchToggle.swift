import SwiftUI

/// The system's switch in its own color (`switchOn`), whatever the tint around it. A toggle in a menu is the system's plain
/// `Toggle`: a menu draws it as a checkmark.
struct SwitchToggle<Label: View>: View {
    @Environment(\.tokens) private var tokens
    @Binding private var isOn: Bool
    private let label: Label

    init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {
        _isOn = isOn
        self.label = label()
    }

    var body: some View {
        Toggle(isOn: $isOn) { label }
            .tint(tokens.color(.switchOn))
    }
}

extension SwitchToggle where Label == Text {
    init(_ title: LocalizedStringKey, isOn: Binding<Bool>) {
        self.init(isOn: isOn) { Text(title) }
    }
}
