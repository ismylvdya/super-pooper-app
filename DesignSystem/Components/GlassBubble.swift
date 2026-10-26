import SwiftUI

extension View {
    /// The iOS 26 glass capsule of the system bar buttons and tab bar, for the bars the app draws itself
    /// (lying sideways). Built with an older SDK it falls back to the bar material in the same capsule.
    @ViewBuilder func glassBubble() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: Capsule())
        } else {
            background(.bar, in: Capsule())
        }
        #else
        background(.bar, in: Capsule())
        #endif
    }
}
