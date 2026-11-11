import SwiftUI

extension View {
    /// `transform` applied only when `condition` holds (a page's own bar items, left out where the page shows as search
    /// results).
    @ViewBuilder func applying<Modified: View>(if condition: Bool, _ transform: (Self) -> Modified) -> some View {
        if condition { transform(self) } else { self }
    }
}
