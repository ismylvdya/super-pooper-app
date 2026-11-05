import SwiftUI

extension View {
    /// The color of the system's controls below this view: the accent of menus and values (`accentSelect`), which
    /// whatever has no color of its own takes too.
    func appControls() -> some View {
        modifier(AppControls())
    }
}

private struct AppControls: ViewModifier {
    @Environment(\.tokens) private var tokens

    func body(content: Content) -> some View {
        content.tint(tokens.color(.accentSelect))
    }
}

/// The system's switch in its own color (`accentSwitch`), whatever the tint around it. A toggle in a menu is the system's
/// plain `Toggle`: a menu draws it as a checkmark, and any style of the app's own would break its rows.
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
            .tint(tokens.color(.accentSwitch))
    }
}

extension SwitchToggle where Label == Text {
    init(_ title: LocalizedStringKey, isOn: Binding<Bool>) {
        self.init(isOn: isOn) { Text(title) }
    }
}
